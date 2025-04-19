variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "github_repository" {
  description = "GitHub repository name (e.g., user/repo)"
  type        = string
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_resource_group" {
  description = "Azure resource group"
  type        = string
  default     = "crypto-gateway-rg"
}

variable "azure_location" {
  description = "Azure location"
  type        = string
  default     = "eastus"
}

variable "azure_client_id" {
  description = "Azure client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure tenant ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_credentials" {
  description = "GCP credentials JSON"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "nomad_address" {
  description = "Nomad server address"
  type        = string
  default     = "http://localhost:4646"
}

variable "nomad_token" {
  description = "Nomad API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  default     = "postgresql://user:password@localhost:5432/payroll"
  sensitive   = true
}