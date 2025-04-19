terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
  }
}

# Providers (no count)
provider "docker" {
  host = terraform.workspace == "dev" ? "unix:///var/run/docker.sock" : null
}

provider "digitalocean" {
  token = terraform.workspace == "staging" ? var.do_token : ""
}

provider "aws" {
  region     = terraform.workspace == "prod" ? var.aws_region : "us-east-1"
  access_key = terraform.workspace == "prod" ? var.aws_access_key : ""
  secret_key = terraform.workspace == "prod" ? var.aws_secret_key : ""
}

provider "azurerm" {
  features {}
  client_id       = terraform.workspace == "prod" ? var.azure_client_id : ""
  client_secret   = terraform.workspace == "prod" ? var.azure_client_secret : ""
  tenant_id       = terraform.workspace == "prod" ? var.azure_tenant_id : ""
  subscription_id = terraform.workspace == "prod" ? var.azure_subscription_id : ""
}

provider "google" {
  credentials = terraform.workspace == "prod" ? var.gcp_credentials : ""
  project     = terraform.workspace == "prod" ? var.gcp_project : ""
  region      = terraform.workspace == "prod" ? var.gcp_region : "us-central1"
}

provider "kubernetes" {
  host                   = terraform.workspace == "dev" ? "" : (terraform.workspace == "staging" ? module.kubernetes.cluster_endpoint : module.kubernetes.cluster_endpoint)
  cluster_ca_certificate = terraform.workspace == "dev" ? "" : base64decode(module.kubernetes.cluster_ca_certificate)
  token                  = terraform.workspace == "dev" ? "" : module.kubernetes.cluster_token
}

provider "nomad" {
  address   = var.nomad_address
  secret_id = var.nomad_token
}

# Modules
module "kubernetes" {
  source = "./modules/kubernetes"

  environment          = terraform.workspace
  do_token             = var.do_token
  aws_region           = var.aws_region
  azure_resource_group = var.azure_resource_group
  azure_location       = var.azure_location
  gcp_project          = var.gcp_project
  gcp_region           = var.gcp_region
  github_repository    = var.github_repository
  database_url         = var.database_url
}

module "nomad" {
  source = "./modules/nomad"

  environment       = terraform.workspace
  nomad_address     = var.nomad_address
  github_repository = var.github_repository
}

module "monitoring" {
  source = "./modules/monitoring"

  environment = terraform.workspace
}