variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod"
  }
}

variable "provider" {
  description = "Cloud provider to deploy to (aws, azure, or digitalocean, ignored in dev)"
  type        = string
  default     = "aws"
  validation {
    condition     = contains(["aws", "azure", "digitalocean"], var.provider)
    error_message = "Provider must be one of: aws, azure, digitalocean"
  }
}

variable "aws_region" {
  description = "AWS region for EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "azure_region" {
  description = "Azure region for AKS cluster"
  type        = string
  default     = "eastus"
}

variable "do_region" {
  description = "DigitalOcean region for DOKS cluster"
  type        = string
  default     = "nyc1"
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "envoy-gateway-cluster"
}

variable "github_repository" {
  description = "GitHub repository for the payment gateway image (e.g., username/repo)"
  type        = string
  default     = "your-username/your-repo"
}

variable "image_tag" {
  description = "Docker image tag for the payment gateway"
  type        = string
  default     = "latest"
}

variable "twilio_sid" {
  description = "Twilio Account SID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "twilio_auth_token" {
  description = "Twilio Auth Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "twilio_phone" {
  description = "Twilio Phone Number"
  type        = string
  default     = ""
}

variable "twilio_webhook_secret" {
  description = "Twilio Webhook Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mqtt_broker" {
  description = "MQTT Broker Address"
  type        = string
  default     = "broker.hivemq.com"
}

variable "mqtt_port" {
  description = "MQTT Broker Port"
  type        = string
  default     = "1883"
}

variable "mqtt_topic" {
  description = "MQTT Topic for Payment Requests"
  type        = string
  default     = "payment/requests"
}

variable "infura_url" {
  description = "Infura URL for Ethereum"
  type        = string
  sensitive   = true
  default     = ""
}

variable "wallet_private_key" {
  description = "Wallet Private Key for Ethereum Transactions"
  type        = string
  sensitive   = true
  default     = ""
}
