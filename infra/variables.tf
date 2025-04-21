variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "github_repository" {
  description = "GitHub repository name (e.g., user/repo)"
  type        = string
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
  default     = "postgresql://user:password@postgres:5432/payroll"
  sensitive   = true
}

variable "modem_count" {
  description = "Number of modems to manage"
  type        = number
  default     = 1
  validation {
    condition     = var.modem_count >= 1 && var.modem_count <= 50
    error_message = "Modem count must be between 1 and 50."
  }
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "do_spaces_access_id" {
  description = "DigitalOcean Spaces access ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "do_spaces_secret_key" {
  description = "DigitalOcean Spaces secret key"
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

variable "gcp_credentials" {
  description = "GCP service account credentials JSON"
  type        = string
  default     = ""
  sensitive   = true
}