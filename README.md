```
     ██╗ █████╗  ██████╗ ██████╗ 
     ██║██╔══██╗██╔════╝██╔════╝ 
     ██║███████║██║     ██║  ███╗
██   ██║██╔══██║██║     ██║   ██║
╚█████╔╝██║  ██║╚██████╗╚██████╔╝
 ╚════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  a rolling venture - proof of concept
```
> problem: deliver weekly pay to employees with sms, and minimal access to laptop/desktop

In an increasingly globalized workforce, businesses face significant challenges in delivering timely, secure, and cost-effective payroll solutions to employees in underserved regions where access to traditional computing infrastructure—such as laptops, desktops, or reliable internet—is limited or nonexistent. These employees, often in rural or developing areas, rely on mobile phones as their primary digital interface, necessitating innovative payment systems that leverage ubiquitous SMS technology. "Just Another Crypto Gateway" addresses this critical gap by providing a robust, scalable, and secure cryptocurrency payment platform that enables employers to disburse funds directly to employees’ mobile phones via SMS, bypassing the constraints of traditional banking systems and legacy payroll infrastructure.

> "just another crypto gateway" is the definitive paradigm shift in global payroll, delivering frictionless financial empowerment to the unbanked and underserved. 

Our blockchain-fueled, SMS-driven platform, enhanced by EMV-powered debit card integration, obliterates the barriers of traditional finance, offering instant, secure, and universally spendable payments. With game-changing cost efficiencies, hyper-scalable architecture, and military-grade security, we’re not just another gateway—we’re the vanguard of the financial inclusion revolution. Our cloud-native, AI-ready ecosystem ensures zero downtime, real-time analytics, and seamless interoperability, slashing TCO by up to 90% while unlocking the full potential of cryptocurrency for every employee, everywhere. Embrace the future of work with a solution that’s as innovative as it is inclusive.

> overview

This guide provides instructions for setting up, developing, testing, and deploying a payment gateway system that supports SMS and MQTT-based Ethereum transactions. The system is designed for both local development (using Docker and KIND) and production deployment (on AWS EKS, Azure AKS, or DigitalOcean DOKS) with Terraform, Docker Compose, GitHub Actions, and Grafana monitoring.
Overview

The payment gateway system includes:

```
+---------------------+       +---------------------+       +---------------------+
|   User (SIP Client) |<----->|    SIP Gateway      |<----->|   Hardware Proxy    |
|                     | SIP   | (Rust, SMS-to-SIP)  | Redis | (Rust, 50 Modems)   |
+---------------------+       +---------------------+       +---------------------+
                                    |                        | Quectel Modems (50) |
                                    |                        | /dev/ttyUSB0-49     |
                                    v                        +---------------------+
+---------------------+       +---------------------+       +---------------------+
| Payment Gateway     |<----->|   Nomad Cluster     |       |   Cellular Network  |
| (Flask, Ethereum)   | HTTP  | (Device Plugin,     |       | (SMS Delivery)      |
|                     |       |  Job Scheduling)    |       +---------------------+
+---------------------+       +---------------------+
                                    |
                                    v
+---------------------+       +---------------------+       +---------------------+
|   Kubernetes        |<----->|   Monitoring        |       |   CI/CD             |
| (EKS/AKS/DOKS,      | Consul| (Prometheus, Grafana)|       | (GitHub Actions,    |
|  Envoy Proxy)       |       |                     |       |  GHCR)              |
+---------------------+       +---------------------+       +---------------------+
```

Backend: A Flask-based Python application (payment_gateway.py) handling SMS (via Twilio) and MQTT (via a public broker) payment/transfer requests.
Kubernetes: Deployed locally with KIND for development or on cloud providers (AWS, Azure, DigitalOcean) for production, using Envoy Proxy for load balancing and JWT authentication.
Monitoring: Prometheus and Grafana for metrics visualization and alerting (e.g., request throughput, latency, error rates).
Testing: Go-based test suite for bandwidth and use case simulation.
CI/CD: GitHub Actions for building and pushing Docker images to GHCR.
Infrastructure: Terraform for managing Kubernetes clusters and networking.

Prerequisites
Local Development

```
Docker: Install Docker Desktop or Docker Engine.
KIND: Kubernetes IN Docker (v0.20.0) for local Kubernetes clusters.curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

```
kubectl: Kubernetes CLI for cluster management.
helm: For deploying Envoy Gateway and monitoring stack.
Terraform: Version >= 1.0 for infrastructure management.
Go: For running the test suite (go.mod specifies version 1.21).
Python: Version 3.8+ for the payment gateway backend.
```
Deployment Variables
```
AWS Credentials: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY or use AWS CLI.
Azure Credentials: Authenticate with az login or set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID.
DigitalOcean Token: Set DIGITALOCEAN_TOKEN or provide via Terraform variable.
GitHub Container Registry (GHCR): Ensure access to push/pull images from your repository.
```
General

A .env file with environment variables (see Environment Variables).
Access to Twilio, Infura, and an Ethereum wallet for testing transactions.
GitHub repository with Actions enabled for CI/CD.

```
Directory Structure
├── .github/
│   └── workflows/
│       └── docker-build-push.yml
├── Dockerfile
├── Dockerfile.tests
├── docker-compose.yml
├── payment_gateway.py
├── requirements.txt
├── prometheus.yml
├── grafana_dashboard.json
├── grafana_provisioning/
│   ├── datasources/
│   │   └── datasource.yml
│   ├── dashboards/
│   │   └── dashboard.yml
├── tests/
│   ├── main_test.go
│   ├── go.mod
│   └── go.sum
├── main.tf
├── variables.tf
├── outputs.tf
├── kind-config.yaml
├── setup-kind.sh
└── .env
```

```
Dockerfiles: Dockerfile for the payment gateway, Dockerfile.tests for the Go test suite.
Docker Compose: Runs the payment gateway, Redis, Prometheus, Grafana, and tester locally.
Tests: Go-based suite for bandwidth and use case testing.
Terraform: Configures local KIND or cloud Kubernetes clusters (AWS, Azure, DigitalOcean).
Monitoring: Prometheus and Grafana configurations for metrics and alerts.
CI/CD: GitHub Actions workflow for building and pushing images.
KIND: Local Kubernetes cluster setup for development.
```

Environment Variables
Create a .env file in the project root with the following variables (do not commit to version control):
```
# Twilio
TWILIO_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE=+1234567890
TWILIO_WEBHOOK_SECRET=your_webhook_secret
```
```
# MQTT
MQTT_BROKER=broker.hivemq.com
MQTT_PORT=1883
MQTT_TOPIC=payment/requests
```
```
# Ethereum
INFURA_URL=https://mainnet.infura.io/v3/your_infura_key
WALLET_PRIVATE_KEY=your_wallet_private_key
```
```
# Rate Limiting
RATE_LIMIT_CALLS=10
RATE_LIMIT_PERIOD=60
```
```
# Redis
REDIS_URL=redis://redis:6379
```
```
# Flask
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
```
```
# Application
MAX_AMOUNT=100.0
ALLOWED_COMMANDS=PAY,TRANSFER
```
```
# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
```
```
# GitHub Repository (for production image)
GITHUB_REPOSITORY=your-username/your-repo
```
```
For production, store sensitive variables (e.g., TWILIO_*, INFURA_URL, WALLET_PRIVATE_KEY) in a secure vault or Terraform Cloud.
Development Setup (Local Docker)
The development environment uses Docker and KIND to run a local Kubernetes cluster with the payment gateway, Envoy Proxy, Redis, and monitoring stack.
Steps
```

Prepare the Environment:

Ensure Docker, KIND, kubectl, helm, Terraform, Go, and Python are installed.

```
Create a terraform.tfvars file:environment       = "dev"
cluster_name      = "envoy-gateway-cluster"
github_repository = "your-username/your-repo"
twilio_sid        = "your_twilio_sid"
twilio_auth_token = "your_twilio_auth_token"
twilio_phone      = "+1234567890"
twilio_webhook_secret = "your_webhook_secret"
infura_url        = "https://mainnet.infura.io/v3/your_infura_key"
wallet_private_key = "your_wallet_private_key"
```



Set Up KIND Cluster:

Run the setup script to build the payment gateway image and create the KIND cluster:chmod +x setup-kind.sh
```
./setup-kind.sh
```

This builds the payment-gateway:latest image and loads it into KIND.


Deploy with Terraform:

Initialize Terraform Workspaces:
```
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
terraform apply
```

Apply the configuration:terraform apply


This deploys:
KIND cluster with Envoy Gateway.
Payment gateway and Redis deployments.
TLS certificates and JWT authentication.

Run Docker Compose:

Start the local monitoring and testing stack:docker-compose up --build
```
This runs:
Payment gateway (accessible at http://localhost:5000 for testing outside Kubernetes).
Redis for rate limiting.
Prometheus (http://localhost:9091) for metrics.
Grafana (http://localhost:3000, login: admin/admin) for dashboards.
Tester service for running Go tests.
```
Verify Deployment:
```
Check Kubernetes resources:kubectl get pods -n default
kubectl get gateway -n default
```
```
Access the payment gateway via Envoy (port 8443):curl --cacert ca.crt https://localhost:8443/sms -H "Authorization: Bearer <jwt_token>" -d '{"From":"+1234567890","Body":"PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"}' -H "Content-Type: application/json"
```
```
Replace <jwt_token> with a valid JWT for your issuer (configured in security_policy).
View metrics in Grafana (http://localhost:3000, dashboard: Payment Gateway Monitoring).
```
Run Tests:
```
Execute the Go test suite locally:docker-compose run tester
```
This tests bandwidth (SMS/MQTT throughput, latency) and use cases (valid/invalid requests, rate limits).
Check test output for results (e.g., throughput in req/s, average latency in ms).

Development Workflow:

Modify payment_gateway.py or tests/main_test.go as needed.
Rebuild the Docker image and reload into KIND:./setup-kind.sh

Reapply Terraform to update deployments:
```
terraform apply
```

Monitor changes in Grafana and test with curl or the test suite.

Production Setup (Cloud Providers)
The production environment deploys the payment gateway to a Kubernetes cluster on AWS (EKS), Azure (AKS), or DigitalOcean (DOKS) using Terraform, pulling the image from GHCR.
Steps

Prepare the Environment:

Configure cloud credentials:
```
AWS: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY or use AWS CLI.
Azure: Run az login or set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID.
DigitalOcean: Set DIGITALOCEAN_TOKEN or provide via do_token.
```
```
Ensure the payment gateway image is pushed to GHCR via GitHub Actions (see CI/CD Setup).
Create a terraform.tfvars file:environment       = "prod"
provider          = "aws" # or "azure" or "digitalocean"
aws_region        = "us-east-1"
azure_region      = "eastus"
do_region         = "nyc1"
do_token          = "your-digitalocean-token"
cluster_name      = "envoy-gateway-cluster"
github_repository = "your-username/your-repo"
image_tag         = "latest"
twilio_sid        = "your_twilio_sid"
twilio_auth_token = "your_twilio_auth_token"
twilio_phone      = "+1234567890"
twilio_webhook_secret = "your_webhook_secret"
infura_url        = "https://mainnet.infura.io/v3/your_infura_key"
wallet_private_key = "your_wallet_private_key"
```
Deploy with Terraform:

Initialize Terraform:
```
terraform init
```
Apply the configuration:
```
terraform apply
```
