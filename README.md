# sms-crypto-gateway
```
      _   _                                 
  ___| |_| |__   ___ _ __ ___ _ __ ___  ___ 
 / _ \ __| '_ \ / _ \ '__/ __| '_ ` _ \/ __|
|  __/ |_| | | |  __/ |  \__ \ | | | | \__ \
 \___|\__|_| |_|\___|_|  |___/_| |_| |_|___/

v1.02 - poc - by chris dickman
```

infra

terraform init
terraform plan
terraform apply

aws eks update-kubeconfig --name envoy-gateway-cluster --region us-east-1

kubectl get pods -n default

kubectl get gateway -n default

curl --cacert ca.crt https://www.example.com -H "Authorization: Bearer <jwt_token>"

app

Instructions to Use
Prerequisites:
A GitHub repository with GHCR enabled.
A GitHub Personal Access Token (PAT) with packages:write scope stored as a secret named GHCR_PAT.
A .env file with environment variables (not committed to the repository).
Tests in a tests/ directory (you'll need to create these; a sample test structure is assumed).

```
├── .github/
│   └── workflows/
│       └── docker-build-push.yml
├── Dockerfile
├── docker-compose.yml
├── payment_gateway.py
├── requirements.txt
├── tests/
│   └── test_payment_gateway.py (create your tests here)
└── .env (not committed)
```

evn
```
GITHUB_REPOSITORY=your-username/your-repo
TWILIO_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE=+1234567890
TWILIO_WEBHOOK_SECRET=your_webhook_secret
MQTT_BROKER=broker.hivemq.com
MQTT_PORT=1883
MQTT_TOPIC=payment/requests
INFURA_URL=https://mainnet.infura.io/v3/your_infura_key
WALLET_PRIVATE_KEY=your_wallet_private_key
RATE_LIMIT_CALLS=10
RATE_LIMIT_PERIOD=60
REDIS_URL=redis://redis:6379
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
MAX_AMOUNT=100.0
ALLOWED_COMMANDS=PAY,TRANSFER
```

Install Docker and Docker Compose.
Run the application:

docker-compose up --build

GitHub Actions Setup:
Add the GitHub PAT as a repository secret named GHCR_PAT in GitHub Settings > Secrets and variables > Actions.
Optionally, add a Codecov token as CODECOV_TOKEN for test coverage reporting.
Push the code to the main branch to trigger the workflow.
The image will be available at ghcr.io/your-username/your-repo/payment-gateway:latest (and other tags based on the metadata action).

tests/test_payment_gateway.py

