use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use serialport::{SerialPort, TTYPort};
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};
use config::Config;
use log::{info, error, debug};
use prometheus::{Counter, Gauge, Registry, TextEncoder};
use std::io::{Read, Write};
use std::sync::Arc;
use serde::{Deserialize, Serialize};
use redis::AsyncCommands;

// SMS Request/Response Structures
#[derive(Serialize, Deserialize)]
struct SmsRequest {
    modem_id: usize,
    recipient: String,
    message: String,
}

#[derive(Serialize, Deserialize)]
struct SmsResponse {
    status: String,
    message_id: Option<String>,
}

// Modem Handler
struct ModemHandler {
    port: TTYPort,
    modem_id: usize,
}

impl ModemHandler {
    fn new(port_path: &str, modem_id: usize) -> Result<Self, Box<dyn std::error::Error>> {
        let port = serialport::new(port_path, 115200)
            .timeout(Duration::from_millis(1000))
            .open_native()?;
        Ok(ModemHandler { port, modem_id })
    }

    fn send_at_command(&mut self, command: &str) -> Result<String, Box<dyn std::error::Error>> {
        let cmd = format!("{}\r\n", command);
        self.port.write_all(cmd.as_bytes())?;
        self.port.flush()?;

        let mut response = String::new();
        let mut buffer = [0; 1024];
        loop {
            let bytes_read = self.port.read(&mut buffer)?;
            response.push_str(std::str::from_utf8(&buffer[..bytes_read])?);
            if response.contains("OK") || response.contains("ERROR") {
                break;
            }
        }
        Ok(response)
    }

    fn configure_sms(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.send_at_command("AT+CMGF=0")?; // PDU mode
        self.send_at_command("AT+CNMI=2,1,0,0,0")?; // New message notifications
        Ok(())
    }

    async fn send_sms(&mut self, recipient: &str, message: &str) -> Result<String, Box<dyn std::error::Error>> {
        // Simplified PDU encoding (use real PDU library in production)
        let pdu = format!("0011000B91{}0000AA{:02X}{}", recipient, message.len(), hex::encode(message));
        let len = pdu.len() / 2;
        self.send_at_command(&format!("AT+CMGS={}", len))?;
        let cmd = format!("{}\x1A", pdu);
        let response = self.send_at_command(&cmd)?;
        Ok(response)
    }

    async fn read_sms(&mut self) -> Result<Option<String>, Box<dyn std::error::Error>> {
        let response = self.send_at_command("AT+CMGL=4")?;
        if response.contains("+CMGL:") {
            Ok(Some(response))
        } else {
            Ok(None)
        }
    }
}

// Proxy State
struct ProxyState {
    modems: Vec<ModemHandler>,
    redis: redis::Client,
    metrics: Metrics,
}

struct Metrics {
    sms_sent: Counter,
    sms_received: Counter,
    modem_load: Gauge,
    registry: Registry,
}

impl Metrics {
    fn new() -> Self {
        let registry = Registry::new();
        let sms_sent = Counter::new("sms_sent_total", "Total SMS sent").unwrap();
        let sms_received = Counter::new("sms_received_total", "Total SMS received").unwrap();
        let modem_load = Gauge::new("modem_load", "Current modem load").unwrap();
        registry.register(Box::new(sms_sent.clone())).unwrap();
        registry.register(Box::new(sms_received.clone())).unwrap();
        registry.register(Box::new(modem_load.clone())).unwrap();
        Metrics { sms_sent, sms_received, modem_load, registry }
    }
}

// API Endpoints
async fn send_sms(
    state: web::Data<Arc<ProxyState>>,
    req: web::Json<SmsRequest>,
) -> impl Responder {
    let modem = &state.modems[req.modem_id];
    let mut redis_conn = state.redis.get_async_connection().await.unwrap();
    match modem.send_sms(&req.recipient, &req.message).await {
        Ok(response) => {
            state.metrics.sms_sent.inc();
            state.metrics.modem_load.inc();
            // Queue for SIP gateway
            redis_conn.lpush("sms_queue", format!("{}:{}", req.recipient, req.message)).await.unwrap();
            HttpResponse::Ok().json(SmsResponse {
                status: "success".to_string(),
                message_id: Some(response),
            })
        }
        Err(e) => HttpResponse::InternalServerError().body(format!("Error: {}", e)),
    }
}

async fn metrics(state: web::Data<Arc<ProxyState>>) -> impl Responder {
    let encoder = TextEncoder::new();
    let metric_families = state.metrics.registry.gather();
    match encoder.encode_to_string(&metric_families) {
        Ok(metrics) => HttpResponse::Ok().body(metrics),
        Err(e) => HttpResponse::InternalServerError().body(format!("Error: {}", e)),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();

    // Load configuration
    let config = Config::builder()
        .add_source(config::File::with_name("config.toml"))
        .build()
        .unwrap()
        .try_deserialize::<std::collections::HashMap<String, String>>()
        .unwrap();

    let redis_url = config.get("redis_url").unwrap();
    let modem_ports: Vec<String> = config.get("modem_ports").unwrap().split(',').map(|s| s.to_string()).collect();
    let api_addr = config.get("api_addr").unwrap();

    // Initialize modems
    let mut modems = Vec::new();
    for (i, port) in modem_ports.iter().enumerate() {
        let mut modem = ModemHandler::new(port, i).unwrap();
        modem.configure_sms().unwrap();
        modems.push(modem);
    }

    // Initialize Redis
    let redis = redis::Client::open(redis_url.as_str()).unwrap();

    // Initialize metrics
    let metrics = Metrics::new();

    // Proxy state
    let state = Arc::new(ProxyState { modems, redis, metrics });

    // Start inbound SMS polling
    let state_clone = state.clone();
    tokio::spawn(async move {
        loop {
            for modem in state_clone.modems.iter() {
                if let Ok(Some(sms)) = modem.read_sms().await {
                    state_clone.metrics.sms_received.inc();
                    let mut redis_conn = state_clone.redis.get_async_connection().await.unwrap();
                    redis_conn.lpush("sms_queue", sms).await.unwrap();
                }
            }
            sleep(Duration::from_secs(5)).await;
        }
    });

    // Start HTTP server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(state.clone()))
            .route("/sms", web::post().to(send_sms))
            .route("/metrics", web::get().to(metrics))
    })
    .bind(api_addr)?
    .run()
    .await
}
