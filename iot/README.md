Hardware Proxy and Nomad Plugin for 50 Modems
This project implements a hardware proxy for 50 Quectel modems, integrated with a Nomad device plugin to manage connectivity, job scheduling, and load balancing in a Nomad cluster. It supports SMS processing for the SIP gateway, enabling bidirectional SMS-to-SIP communication.
Features

Hardware Proxy: Rust-based proxy managing 50 modems via USB, exposing a REST API for SMS operations.
Nomad Device Plugin: Go-based plugin to fingerprint modems as Nomad devices, enabling scheduling.
Job Scheduling: Nomad jobs for running the proxy and processing SMS tasks across modems.
Load Handling: Bin-packing, anti-affinity, and Consul health checks for balanced modem usage.
Monitoring: Prometheus metrics and Grafana dashboards for SMS throughput and modem load.
Integration: Connects with the SIP gateway and Redis for message queuing.

Prerequisites

Hardware:
50 Quectel modems (e.g., EC25) connected via USB to Nomad client nodes.
Linux hosts with USB ports (e.g., 5 nodes, each with 10 modems).


Software:
Nomad 1.9+, Consul, Redis, Prometheus, Grafana.
Docker for building and running the proxy/plugin.
Rust 1.74+ and Go 1.21+ for local development.


Configuration:
SIM cards with SMS service enabled.
Nomad cluster with client nodes in the dialout group for serial access.



Setup

Clone the Repository:
git clone <repository-url>
cd modem-proxy


Configure Modems:

Connect modems to USB ports (e.g., /dev/ttyUSB0 to /dev/ttyUSB49).
Add user to dialout group:sudo usermod -a -G dialout $USER


Verify modem detection:ls /dev/ttyUSB*




Update Configuration:

Edit config.toml to match modem ports and Redis URL:redis_url = "redis://redis:6379"
api_addr = "0.0.0.0:8080"
modem_ports = "/dev/ttyUSB0,/dev/ttyUSB1,...,/dev/ttyUSB49"




Install Nomad Plugin:

Copy modem-plugin to /opt/nomad/plugins/ on each client node.
Update Nomad client configuration (/etc/nomad.d/client.hcl):plugin "quectel_modem" {
  config {
    enabled = true
  }
}




Build and Run with Docker:

Build the image:docker build -t sms-proxy .


Run with Docker Compose (update docker-compose.yml from payment gateway):sms-proxy:
  image: sms-proxy
  devices:
    - /dev/ttyUSB0:/dev/ttyUSB0
    - /dev/ttyUSB1:/dev/ttyUSB1
    # ... add all 50 modems
  network_mode: host
  volumes:
    - ./config.toml:/etc/sms-proxy/config.toml
  depends_on:
    - redis




Deploy Nomad Job:

Submit the job:nomad job run sms_proxy.nomad


Verify status:nomad status sms_proxy





Usage

Send SMS:

Use the REST API:curl -X POST http://<node-ip>:8080/sms \
  -H "Content-Type: application/json" \
  -d '{"modem_id": 0, "recipient": "+1234567890", "message": "PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"}'


The proxy sends the SMS via the specified modem and queues it for the SIP gateway.


Receive SMS:

Inbound SMS are polled every 5 seconds and queued in Redis.
The SIP gateway (from previous artifact) processes the queue and forwards to SIP endpoints.


Monitor Load:

Access Prometheus metrics: http://<node-ip>:9090/metrics
View Grafana dashboard for SMS throughput and modem load.



Monitoring

Prometheus:
Update prometheus.yml (from payment gateway) to scrape proxy metrics:- job_name: 'sms-proxy'
  static_configs:
    - targets: ['<node-ip>:9090']




Grafana:
Import grafana_dashboard.json to visualize:
sms_sent_total: Total SMS sent.
sms_received_total: Total SMS received.
modem_load: Current modem load.





Testing

Local Testing:

Run a single node Nomad cluster in dev mode:nomad agent -dev


Submit the job and test API endpoints.


End-to-End Testing:

Send SMS via API and verify delivery on an external phone.
Send SMS to a modem’s SIM and check Redis queue/SIP gateway.


Load Testing:

Simulate high SMS volume:for i in {1..1000}; do curl -X POST http://<node-ip>:8080/sms -d '{"modem_id": 0, "recipient": "+1234567890", "message": "Test"}'; done


Monitor Grafana for load distribution and modem usage.



Troubleshooting

Modem Detection:
Check dmesg for USB device errors.
Verify ports in config.toml match ls /dev/ttyUSB*.


Nomad Scheduling:
Inspect logs: nomad alloc logs <alloc-id>
Ensure plugin is loaded: nomad node status


API Errors:
Check proxy logs: docker logs <container-id>
Verify Redis connectivity: redis-cli -h redis ping


High Load:
Increase count in sms_processor group.
Adjust affinity rules for better signal strength.



Security Considerations

API Access: Restrict /sms endpoint to trusted clients (e.g., SIP gateway).
TLS: Enable HTTPS for the proxy API in production.
Nomad ACLs: Configure ACLs to limit job submissions.
Modem Firmware: Update Quectel firmware to mitigate vulnerabilities.

Extending the System

Scalability: Add more modems by updating config.toml and scaling client nodes.
Advanced Scheduling: Use Nomad’s spread stanza to distribute tasks across datacenters.
Fault Tolerance: Implement modem failover by monitoring signal strength.
Metrics: Add custom metrics (e.g., SMS latency, error rates).

Integration with SIP Gateway

The proxy queues SMS in Redis (sms_queue), which the SIP gateway processes.
Update the SIP gateway’s main.rs to read from the queue:let mut redis_conn = redis.get_async_connection().await.unwrap();
let sms: Option<String> = redis_conn.lpop("sms_queue", None).await.unwrap();


Deploy both in the same Nomad cluster or Kubernetes namespace.

References

Nomad Device Plugins: https://developer.hashicorp.com/nomad/docs/internals/plugins/device
Quectel AT Commands Manual (requires Quectel sign-in).
Nomad Networking: https://developer.hashicorp.com/nomad/docs/concepts/networking[](https://developer.hashicorp.com/nomad/docs/networking)
Consul Service Mesh: https://developer.hashicorp.com/nomad/docs/integrations/consul-connect[](https://developer.hashicorp.com/nomad/docs/integrations/consul/service-mesh)


Last Updated: April 19, 2025

