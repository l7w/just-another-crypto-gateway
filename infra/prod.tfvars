environment = "prod"
github_repository = "user/just-another-crypto-gateway"
aws_region = "us-east-1"
aws_access_key = "${AWS_ACCESS_KEY}"
aws_secret_key = "${AWS_SECRET_KEY}"
azure_resource_group = "crypto-gateway-rg"
azure_location = "eastus"
azure_client_id = "${AZURE_CLIENT_ID}"
azure_client_secret = "${AZURE_CLIENT_SECRET}"
azure_tenant_id = "${AZURE_TENANT_ID}"
azure_subscription_id = "${AZURE_SUBSCRIPTION_ID}"
gcp_credentials = "${GCP_CREDENTIALS}"
gcp_project = "crypto-gateway-prod"
gcp_region = "us-central1"
nomad_address = "http://nomad-prod:4646"
database_url = "postgresql://user:password@prod-db:5432/payroll"