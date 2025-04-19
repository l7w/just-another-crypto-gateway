# Just Another Crypto Gateway - Terraform Configuration

This Terraform configuration manages the infrastructure for "Just Another Crypto Gateway," a cryptocurrency payment platform using SMS and EMV debit cards. It uses Terraform Workspaces to support:

- **Development**: Local Docker (Docker Compose, KIND, single Nomad node).
- **Staging**: DigitalOcean Droplets (DOKS, Nomad).
- **Production**: Multi-cloud (AWS EKS, Azure AKS, GCP GKE, Nomad).

## Components

- **Payment Gateway**: Flask-based Python app for SMS/MQTT payments and debit card top-ups.
- **SIP Gateway**: Rust-based SMS-to-SIP service.
- **Hardware Proxy**: Rust-based modem manager (50 Quectel modems).
- **Nomad Device Plugin**: Go-based modem scheduler.
- **Web3-React Middleware**: TypeScript/React app for wallet connections and database sync.
- **Monitoring**: Prometheus and Grafana.
- **Database**: PostgreSQL (accounting), Redis (queuing/rate limiting).

## Prerequisites

- **Terraform**: v1.5.7+.
- **Docker**: For local development.
- **DigitalOcean**: Account and API token for staging.
- **AWS**: Account, access/secret keys for production.
- **Azure**: Subscription, client ID/secret, tenant ID for production.
- **GCP**: Project, credentials JSON for production.
- **Nomad**: Server for modem tasks (v1.8+).
- **Kubernetes**: KIND (dev), DOKS (staging), EKS/AKS/GKE (prod).
- **Secrets**:
  - `DO_TOKEN`
  - `AWS_ACCESS_KEY`, `AWS_SECRET_KEY`
  - `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
  - `GCP_CREDENTIALS`
  - `NOMAD_TOKEN`, `NOMAD_ADDR`
  - `DATABASE_URL`
  - `KUBE_CONFIG`

## Directory Structure

```plaintext
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
├── nomad/
│   ├── config/
│   │   ├── server.hcl
├── hardware-proxy/
│   ├── config.toml
├── prometheus.yml
├── grafana_dashboard.json
```

## Nomad Setup

1. **Nomad Agent Configuration**:

   - Create `nomad/config/server.hcl`:

     ```hcl
     datacenter = "dc1"
     server {
       enabled = true
       bootstrap_expect = 1
     }
     client {
       enabled = true
       node_class = "modem-enabled"
       options {
         "driver.docker.enable" = "1"
       }
     }
     ```

   - For `staging`/`prod`, configure multi-node clusters with USB hubs.

2. **Modem Configuration**:

   - Update `hardware-proxy/config.toml` with modem ports:

     ```toml
     [modems]
     % for i in range(50)
     modem_${i} = "/dev/ttyUSB${i}"
     % endfor
     [redis]
     url = "redis://redis:6379"
     ```

   - In `dev`, simulate 1 modem; `staging`/`prod` use 50.

3. **Nomad Jobs**:

   - **Hardware Proxy**: Manages modems, exposes HTTP (`8082`) and metrics (`9090`) endpoints.
   - **Device Plugin**: Fingerprints modems, runs as a system job.

## Setup

1. **Clone Repository**:

   ```bash
   git clone <repository-url>
   cd just-another-crypto-gateway
   ```

2. **Install Terraform**:

   ```bash
   brew install terraform
   ```

3. **Configure Secrets**:

   - Add secrets to GitHub Secrets.

   - Set environment variables or update `.tfvars`:

     ```bash
     export TF_VAR_do_token=$DO_TOKEN
     export TF_VAR_nomad_token=$NOMAD_TOKEN
     ```

4. **Initialize Terraform**:

   ```bash
   terraform init
   ```

## Workspaces

1. **Development (**`dev`**)**:

   - Config: `dev.tfvars`

   - Setup:

     ```bash
     terraform workspace select dev || terraform workspace new dev
     terraform apply -var-file=dev.tfvars -var="modem_count=1"
     docker-compose up --build
     nomad job run modules/nomad/sms_proxy.nomad
     nomad job run modules/nomad/device_plugin.nomad
     ```

   - Access: `http://localhost:8082` (Hardware Proxy), `http://localhost:4646` (Nomad UI).

2. **Staging (**`staging`**)**:

   - Config: `staging.tfvars`

   - Setup:

     ```bash
     terraform workspace select staging || terraform workspace new staging
     terraform apply -var-file=staging.tfvars -var="modem_count=50"
     ```

3. **Production (**`prod`**)**:

   - Config: `prod.tfvars`

   - Setup:

     ```bash
     terraform workspace select prod || terraform workspace new prod
     terraform apply -var-file=prod.tfvars -var="modem_count=50"
     ```

## GitHub Actions

- Trigger deployment:

  ```bash
  gh workflow run deploy-prod.yml -f workspace=staging
  gh workflow run deploy-prod.yml -f workspace=prod
  ```

## Usage

1. **Test SMS**:

   ```bash
   curl -X POST http://<nomad-ip>:8082/sms -d '{"modem_id": 0, "recipient": "+1234567890", "message": "PAY 100 USDC"}'
   ```

2. **Monitor**:

   - Prometheus: `http://<nomad-ip>:9090`
   - Grafana: `http://<grafana-ip>:3000`

## Troubleshooting

- **Nomad Job Failures**: Check `nomad status sms_proxy` and logs.
- **Modem Issues**: Verify `/dev/ttyUSB*` paths in `config.toml`.
- **Terraform Errors**: Ensure `NOMAD_TOKEN` and `NOMAD_ADDR` are set.

## Security

- Use Nomad ACLs to restrict job submissions.
- Enable mTLS for Nomad API in `prod`.
- Validate modem firmware versions.

## References

- Nomad: https://developer.hashicorp.com/nomad/docs
- Terraform: https://www.terraform.io/docs

---

*Last Updated: April 19, 2025*