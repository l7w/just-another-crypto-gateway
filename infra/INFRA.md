Just Another Crypto Gateway - Terraform Configuration
This Terraform configuration manages the infrastructure for "Just Another Crypto Gateway," a cryptocurrency payment platform using SMS and EMV debit cards. It uses Terraform Workspaces to support:

Development: Local Docker (Docker Compose, KIND, single Nomad node).
Staging: DigitalOcean Droplets (DOKS, Nomad).
Production: Multi-cloud (AWS EKS, Azure AKS, GCP GKE, Nomad).

Components

Payment Gateway: Flask-based Python app for SMS/MQTT payments and debit card top-ups.
SIP Gateway: Rust-based SMS-to-SIP service.
Hardware Proxy: Rust-based modem manager (50 Quectel modems).
Nomad Device Plugin: Go-based modem scheduler.
Web3-React Middleware: TypeScript/React app for wallet connections and database sync.
Monitoring: Prometheus and Grafana.
Database: PostgreSQL (accounting), Redis (queuing/rate limiting).

Prerequisites

Terraform: v1.5.7+.
Docker: For local development.
DigitalOcean: Account and API token for staging.
AWS: Account, access/secret keys for production.
Azure: Subscription, client ID/secret, tenant ID for production.
GCP: Project, credentials JSON for production.
Nomad: Server for modem tasks.
Kubernetes: KIND (dev), DOKS (staging), EKS/AKS/GKE (prod).
Secrets:
DO_TOKEN
AWS_ACCESS_KEY, AWS_SECRET_KEY
AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
GCP_CREDENTIALS
NOMAD_TOKEN, NOMAD_ADDR
DATABASE_URL
KUBE_CONFIG


```
Directory Structure
.
├── main.tf
├── variables.tf
├── outputs.tf
├── dev.tfvars
├── staging.tfvars
├── prod.tfvars
├── modules/
│   ├── kubernetes/
│   │   ├── main.tf
│   ├── nomad/
│   │   ├── main.tf
│   │   ├── sms_proxy.nomad.tmpl
│   │   ├── device_plugin.nomad.tmpl
│   ├── monitoring/
│   │   ├── main.tf
│   │   ├── prometheus.yml
│   │   ├── grafana_dashboard.json
├── docker-compose.yml
├── sms_proxy.nomad
├── prometheus.yml
├── grafana_dashboard.json
```

Setup

Clone Repository:
git clone <repository-url>
cd just-another-crypto-gateway


Install Terraform:
brew install terraform


Configure Secrets:

Add secrets to GitHub Secrets for CI/CD.

Create .tfvars files or set environment variables:
export TF_VAR_do_token=$DO_TOKEN
export TF_VAR_aws_access_key=$AWS_ACCESS_KEY
# ... other variables




Initialize Terraform:
terraform init



Workspaces

Development (dev):

Uses Docker Compose for local services.

Config: dev.tfvars

Setup:
terraform workspace select dev || terraform workspace new dev
terraform apply -var-file=dev.tfvars


Access:

Payment Gateway: http://localhost:8080
Middleware: http://localhost:3000
Prometheus: http://localhost:9090
Grafana: http://localhost:3001




Staging (staging):

Uses DigitalOcean DOKS and Nomad.

Config: staging.tfvars

Setup:
terraform workspace select staging || terraform workspace new staging
terraform apply -var-file=staging.tfvars


Access: Use kubectl or Nomad UI with cluster endpoints.



Production (prod):

Uses AWS EKS, Azure AKS, GCP GKE, and Nomad.

Config: prod.tfvars

Setup:
terraform workspace select prod || terraform workspace new prod
terraform apply -var-file=prod.tfvars


Access: Multi-cloud endpoints via outputs.tf.




GitHub Actions Integration

Workflow: deploy-prod.yml

Trigger deployment:
gh workflow run deploy-prod.yml -f workspace=staging
gh workflow run deploy-prod.yml -f workspace=prod


Secrets:

Store cloud credentials and NOMAD_TOKEN in GitHub Secrets.
Update KUBE_CONFIG post-deployment for verification.



Usage

Local Development:

Run Docker Compose:
docker-compose up --build


Test SMS: curl -X POST http://localhost:8082/sms -d '{"modem_id": 0, "recipient": "+1234567890", "message": "PAY 100 USDC"}'



Staging/Production:

Verify pods: kubectl get pods -n default
Check Nomad: nomad status sms_proxy
Monitor: Access Grafana (outputs.grafana_url).



Troubleshooting

Terraform Errors: Check provider credentials and .tfvars files.
Kubernetes Issues: Verify cluster connectivity with kubectl cluster-info.
Nomad Failures: Ensure NOMAD_ADDR and NOMAD_TOKEN are valid.
Modem Connectivity: Update config.toml with correct /dev/ttyUSB* ports.

Security Considerations

IAM Roles: Use least-privilege policies for AWS/Azure/GCP.
Secrets: Encrypt sensitive variables in .tfvars.
TLS: Enable HTTPS for services in production.
Nomad ACLs: Restrict job submissions with NOMAD_TOKEN.

Extending the System

Scalability: Increase node counts in main.tf for larger clusters.
Cloud Providers: Add more providers (e.g., Oracle Cloud) in main.tf.
Components: Extend modules for new services.

References

Terraform: https://www.terraform.io/docs
DigitalOcean: https://www.digitalocean.com/docs
AWS EKS: https://aws.amazon.com/eks
Azure AKS: https://azure.microsoft.com/services/kubernetes-service
GCP GKE: https://cloud.google.com/kubernetes-engine


Last Updated: April 19, 2025
