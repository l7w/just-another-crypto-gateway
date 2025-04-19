import os
import re
import uuid
import logging
import asyncio
from typing import Dict, Tuple, Optional
from dotenv import load_dotenv
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
from twilio.request_validator import RequestValidator
import paho.mqtt.client as mqtt
from web3 import Web3
from web3.exceptions import Web3Exception
from flask import Flask, request, abort
from ratelimit import limits, sleep_and_retry
from functools import wraps
import redis
from eth_account import Account
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter, Histogram

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Configuration with defaults
CONFIG = {
    'TWILIO_SID': os.getenv('TWILIO_SID', ''),
    'TWILIO_AUTH_TOKEN': os.getenv('TWILIO_AUTH_TOKEN', ''),
    'TWILIO_PHONE': os.getenv('TWILIO_PHONE', ''),
    'TWILIO_WEBHOOK_SECRET': os.getenv('TWILIO_WEBHOOK_SECRET', str(uuid.uuid4())),
    'MQTT_BROKER': os.getenv('MQTT_BROKER', 'broker.hivemq.com'),
    'MQTT_PORT': int(os.getenv('MQTT_PORT', 1883)),
    'MQTT_TOPIC': os.getenv('MQTT_TOPIC', 'payment/requests'),
    'INFURA_URL': os.getenv('INFURA_URL', ''),
    'WALLET_PRIVATE_KEY': os.getenv('WALLET_PRIVATE_KEY', ''),
    'RATE_LIMIT_CALLS': int(os.getenv('RATE_LIMIT_CALLS', 10)),
    'RATE_LIMIT_PERIOD': int(os.getenv('RATE_LIMIT_PERIOD', 60)),
    'REDIS_URL': os.getenv('REDIS_URL', 'redis://redis:6379'),
    'FLASK_HOST': os.getenv('FLASK_HOST', '0.0.0.0'),
    'FLASK_PORT': int(os.getenv('FLASK_PORT', 5000)),
    'MAX_AMOUNT': float(os.getenv('MAX_AMOUNT', 100.0)),
    'ALLOWED_COMMANDS': os.getenv('ALLOWED_COMMANDS', 'PAY,TRANSFER').split(',')
}

# Initialize clients
try:
    twilio_client = Client(CONFIG['TWILIO_SID'], CONFIG['TWILIO_AUTH_TOKEN'])
    twilio_validator = RequestValidator(CONFIG['TWILIO_AUTH_TOKEN'])
    web3 = Web3(Web3.HTTPProvider(CONFIG['INFURA_URL']))
    mqtt_client = mqtt.Client(client_id=f"payment-gateway-{uuid.uuid4()}")
    redis_client = redis.Redis.from_url(CONFIG['REDIS_URL'])
except Exception as e:
    logger.error(f"Failed to initialize clients: {e}")
    raise

# Flask app for webhook
app = Flask(__name__)
metrics = PrometheusMetrics(app)

# Prometheus metrics
http_requests_total = Counter('http_requests_total', 'Total HTTP requests', ['path', 'status'])
mqtt_requests_total = Counter('mqtt_requests_total', 'Total MQTT requests', ['status'])
http_request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration', ['path'])
mqtt_request_duration = Histogram('mqtt_request_duration_seconds', 'MQTT request duration')
rate_limit_exceeded_total = Counter('rate_limit_exceeded_total', 'Total rate limit violations')

class PaymentGateway:
    def __init__(self):
        self.wallets: Dict[str, str] = {CONFIG['TWILIO_PHONE']: CONFIG['WALLET_PRIVATE_KEY']}
        self.rate_limits: Dict[str, int] = {}
        self.connect_mqtt()

    def connect_mqtt(self):
        """Connect to MQTT broker and subscribe to topic."""
        mqtt_client.on_connect = self.on_connect
        mqtt_client.on_message = self.on_message
        try:
            mqtt_client.connect(CONFIG['MQTT_BROKER'], CONFIG['MQTT_PORT'], 60)
            mqtt_client.loop_start()
            logger.info("Connected to MQTT broker")
        except Exception as e:
            logger.error(f"Failed to connect to MQTT: {e}")
            raise

    def on_connect(self, client, userdata, flags, rc):
        """Callback for MQTT connection."""
        if rc == 0:
            client.subscribe(CONFIG['MQTT_TOPIC'])
            logger.info(f"Subscribed to {CONFIG['MQTT_TOPIC']}")
        else:
            logger.error(f"MQTT connection failed with code {rc}")
            raise ConnectionError(f"MQTT connection failed with code {rc}")

    def on_message(self, client, userdata, msg):
        """Handle incoming MQTT messages."""
        try:
            start_time = time.time()
            message = msg.payload.decode()
            sender = msg.topic
            asyncio.create_task(self.process_request(sender, message, source='mqtt'))
            mqtt_request_duration.observe(time.time() - start_time)
            mqtt_requests_total.labels(status='success').inc()
        except Exception as e:
            logger.error(f"Error processing MQTT message: {e}")
            mqtt_requests_total.labels(status='error').inc()

    def validate_twilio_request(self, f):
        """Decorator to validate Twilio webhook requests."""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            signature = request.headers.get('X-Twilio-Signature', '')
            url = request.url
            post_data = request.form.to_dict()
            if not twilio_validator.validate(url, post_data, signature):
                logger.warning("Invalid Twilio signature")
                http_requests_total.labels(path='/sms', status='403').inc()
                abort(403)
            return f(*args, **kwargs)
        return decorated_function

    def sanitize_input(self, input_str: str) -> str:
        """Sanitize input to prevent injection attacks."""
        return re.sub(r'[^\w\s.:,0-9]', '', input_str.strip())

    def validate_phone(self, phone: str) -> bool:
        """Validate phone number format."""
        phone_pattern = r'^\+?[1-9]\d{1,14}$'
        return bool(re.match(phone_pattern, phone))

    @sleep_and_retry
    @limits(calls=CONFIG['RATE_LIMIT_CALLS'], period=CONFIG['RATE_LIMIT_PERIOD'])
    async def process_request(self, sender: str, body: str, source: str = 'sms') -> None:
        """Process payment or transfer request."""
        try:
            start_time = time.time()
            body = self.sanitize_input(body)
            if source == 'sms' and not self.validate_phone(sender):
                raise ValueError("Invalid phone number")

            rate_limit_key = f"rate_limit:{sender}"
            request_count = redis_client.get(rate_limit_key)
            if request_count and int(request_count) >= CONFIG['RATE_LIMIT_CALLS']:
                rate_limit_exceeded_total.inc()
                raise ValueError("Rate limit exceeded")

            is_valid, data = self.validate_request(body)
            if not is_valid:
                raise ValueError("Invalid request format")

            if sender not in self.wallets:
                raise ValueError("Unauthorized sender")

            private_key = self.wallets[sender]
            tx_hash = await self.execute_transaction(
                private_key=private_key,
                amount=data["amount"],
                recipient=data["recipient"],
                command=data["command"]
            )

            redis_client.incr(rate_limit_key)
            redis_client.expire(rate_limit_key, CONFIG['RATE_LIMIT_PERIOD'])

            logger.info(f"Transaction sent: {tx_hash.hex()} from {sender} via {source}")
            if source == 'sms':
                await self.send_sms(sender, f"Transaction successful: {tx_hash.hex()}")
                http_request_duration.labels(path='/sms').observe(time.time() - start_time)
                http_requests_total.labels(path='/sms', status='204').inc()
            else:
                mqtt_client.publish(f"{CONFIG['MQTT_TOPIC']}/response", f"Transaction successful: {tx_hash.hex()}")

        except Exception as e:
            logger.error(f"Error processing {source} request from {sender}: {e}")
            error_msg = f"Error: {str(e)}"
            if source == 'sms':
                await self.send_sms(sender, error_msg)
                http_request_duration.labels(path='/sms').observe(time.time() - start_time)
                http_requests_total.labels(path='/sms', status='500').inc()
            else:
                mqtt_requests_total.labels(status='error').inc()

    async def send_sms(self, to_number: str, message: str) -> None:
        """Send SMS response."""
        try:
            if not self.validate_phone(to_number):
                raise ValueError("Invalid recipient phone number")
            twilio_client.messages.create(
                body=message[:160],
                from_=CONFIG['TWILIO_PHONE'],
                to=to_number
            )
            logger.info(f"Sent SMS to {to_number}")
        except TwilioRestException as e:
            logger.error(f"Failed to send SMS: {e}")
            raise

    def validate_request(self, message: str) -> Tuple[bool, Dict]:
        """Validate payment/transfer request format."""
        pattern = r'^(PAY|TRANSFER)\s+(\d+\.?\d*)\s+(0x[a-fA-F0-9]{40})$'
        match = re.match(pattern, message)
        if not match:
            return False, {}
        command, amount, recipient = match.groups()

        try:
            if command not in CONFIG['ALLOWED_COMMANDS']:
                return False, {}
            amount = float(amount)
            if amount <= 0 or amount > CONFIG['MAX_AMOUNT']:
                return False, {}
            if not web3.isAddress(recipient):
                return False, {}
            return True, {"command": command, "amount": amount, "recipient": recipient}
        except ValueError:
            return False, {}

    async def execute_transaction(self, private_key: str, amount: float, recipient: str, command: str) -> bytes:
        """Execute Ethereum transaction."""
        try:
            account = Account.from_key(private_key)
            nonce = web3.eth.getTransactionCount(account.address)
            amount_wei = web3.toWei(amount, 'ether')

            gas_estimate = web3.eth.estimateGas({
                'to': recipient,
                'value': amount_wei,
                'from': account.address
            })

            tx = {
                'nonce': nonce,
                'to': recipient,
                'value': amount_wei,
                'gas': gas_estimate,
                'gasPrice': web3.eth.gas_price,
                'chainId': web3.eth.chain_id
            }

            signed_tx = web3.eth.account.sign_transaction(tx, private_key)
            tx_hash = web3.eth.sendRawTransaction(signed_tx.rawTransaction)
            return tx_hash
        except Web3Exception as e:
            logger.error(f"Transaction failed: {e}")
            raise

    @app.route('/sms', methods=['POST'])
    @validate_twilio_request
    async def sms_webhook(self):
        """Handle Twilio SMS webhook."""
        try:
            from_number = request.form.get('From')
            body = request.form.get('Body')
            if not from_number or not body:
                http_requests_total.labels(path='/sms', status='400').inc()
                abort(400)
            await self.process_request(from_number, body, source='sms')
            return '', 204
        except Exception as e:
            logger.error(f"Webhook error: {e}")
            http_requests_total.labels(path='/sms', status='500').inc()
            abort(500)

async def main():
    gateway = PaymentGateway()
    from threading import Thread
    flask_thread = Thread(target=lambda: app.run(
        host=CONFIG['FLASK_HOST'],
        port=CONFIG['FLASK_PORT'],
        debug=False
    ))
    flask_thread.daemon = True
    flask_thread.start()
    logger.info(f"Flask webhook server running on {CONFIG['FLASK_HOST']}:{CONFIG['FLASK_PORT']}")

    while True:
        await asyncio.sleep(10)

if __name__ == "__main__":
    asyncio.run(main())
