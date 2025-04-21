variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name (e.g., user/repo)"
  type        = string
}

variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "modem_count" {
  description = "Number of modems to manage"
  type        = number
  default     = 1
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = ""
}

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = ""
}

variable "gcp_credentials" {
  description = "GCP credentials JSON"
  type        = string
  default     = ""
}

# DigitalOcean Kubernetes Cluster (staging)
resource "digitalocean_kubernetes_cluster" "doks" {
  count = var.environment == "staging" ? 1 : 0
  name   = "crypto-gateway-staging"
  region = "nyc1"
  version = "1.28.2-do.0"
  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 3
  }
}

# AWS EKS Cluster (prod)
resource "aws_eks_cluster" "eks" {
  count = var.environment == "prod" ? 1 : 0
  name     = "crypto-gateway-prod"
  role_arn = aws_iam_role.eks_role[0].arn
  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
  }
}

resource "aws_iam_role" "eks_role" {
  count = var.environment == "prod" ? 1 : 0
  name = "crypto-gateway-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_subnet" "eks_subnet" {
  count = var.environment == "prod" ? 2 : 0
  vpc_id = aws_vpc.eks_vpc[0].id
  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
}

resource "aws_vpc" "eks_vpc" {
  count = var.environment == "prod" ? 1 : 0
  cidr_block = "10.0.0.0/16"
}

# GCP GKE Cluster (prod)
resource "google_container_cluster" "gke" {
  count = var.environment == "prod" ? 1 : 0
  name     = "crypto-gateway-prod"
  location = var.gcp_region
  initial_node_count = 3
  node_config {
    machine_type = "e2-medium"
  }
}

# Redis Deployment
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = "default"
  }
  spec {
    replicas = var.environment == "prod" ? 3 : 1
    selector {
      match_labels = {
        app = "redis"
      }
    }
    template {
      metadata {
        labels = {
          app = "redis"
        }
      }
      spec {
        container {
          image = "redis:7"
          name  = "redis"
          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

# Redis Service
resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = "default"
  }
  spec {
    selector = {
      app = "redis"
    }
    port {
      port        = 6379
      target_port = 6379
    }
    type = "ClusterIP"
  }
}

# PostgreSQL Deployment
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = "default"
  }
  spec {
    replicas = var.environment == "prod" ? 3 : 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          image = "postgres:15"
          name  = "postgres"
          port {
            container_port = 5432
          }
          env {
            name  = "POSTGRES_USER"
            value = "user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "password"
          }
          env {
            name  = "POSTGRES_DB"
            value = "payroll"
          }
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = "default"
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

# Payment Gateway Deployment
resource "kubernetes_deployment" "payment_gateway" {
  metadata {
    name      = "payment-gateway"
    namespace = "default"
  }
  spec {
    replicas = var.environment == "prod" ? 3 : 1
    selector {
      match_labels = {
        app = "payment-gateway"
      }
    }
    template {
      metadata {
        labels = {
          app = "payment-gateway"
        }
      }
      spec {
        container {
          image = "ghcr.io/${var.github_repository}/payment-gateway:latest"
          name  = "payment-gateway"
          port {
            container_port = 8080
          }
          env {
            name  = "REDIS_URL"
            value = "redis://redis:6379"
          }
          env {
            name  = "DATABASE_URL"
            value = var.database_url
          }
        }
      }
    }
  }
}

# Payment Gateway Service
resource "kubernetes_service" "payment_gateway" {
  metadata {
    name      = "payment-gateway"
    namespace = "default"
  }
  spec {
    selector = {
      app = "payment-gateway"
    }
    port {
      port        = 8080
      target_port = 8080
    }
    type = var.environment == "dev" ? "NodePort" : "ClusterIP"
  }
}

# SIP Gateway Deployment
resource "kubernetes_deployment" "sip_gateway" {
  metadata {
    name      = "sip-gateway"
    namespace = "default"
  }
  spec {
    replicas = var.environment == "prod" ? 3 : 1
    selector {
      match_labels = {
        app = "sip-gateway"
      }
    }
    template {
      metadata {
        labels = {
          app = "sip-gateway"
        }
      }
      spec {
        container {
          image = "ghcr.io/${var.github_repository}/sip-gateway:latest"
          name  = "sip-gateway"
          port {
            container_port = 8081
          }
          env {
            name  = "REDIS_URL"
            value = "redis://redis:6379"
          }
        }
      }
    }
  }
}

# SIP Gateway Service
resource "kubernetes_service" "sip_gateway" {
  metadata {
    name      = "sip-gateway"
    namespace = "default"
  }
  spec {
    selector = {
      app = "sip-gateway"
    }
    port {
      port        = 8081
      target_port = 8081
    }
    type = var.environment == "dev" ? "NodePort" : "ClusterIP"
  }
}

# Middleware Deployment
resource "kubernetes_deployment" "middleware" {
  metadata {
    name      = "middleware"
    namespace = "default"
  }
  spec {
    replicas = var.environment == "prod" ? 3 : 1
    selector {
      match_labels = {
        app = "middleware"
      }
    }
    template {
      metadata {
        labels = {
          app = "middleware"
        }
      }
      spec {
        container {
          image = "ghcr.io/${var.github_repository}/middleware:latest"
          name  = "middleware"
          port {
            container_port = 3000
          }
          env {
            name  = "DATABASE_URL"
            value = var.database_url
          }
        }
      }
    }
  }
}

# Middleware Service
resource "kubernetes_service" "middleware" {
  metadata {
    name      = "middleware"
    namespace = "default"
  }
  spec {
    selector = {
      app = "middleware"
    }
    port {
      port        = 3000
      target_port = 3000
    }
    type = var.environment == "dev" ? "NodePort" : "ClusterIP"
  }
}

# Outputs
output "cluster_endpoint" {
  value = var.environment == "staging" ? digitalocean_kubernetes_cluster.doks[0].endpoint : (
            var.environment == "prod" ? aws_eks_cluster.eks[0].endpoint : "")
}

output "cluster_ca_certificate" {
  value = var.environment == "staging" ? digitalocean_kubernetes_cluster.doks[0].cluster_ca_certificate : (
            var.environment == "prod" ? aws_eks_cluster.eks[0].certificate_authority[0].data : "")
}

output "cluster_token" {
  value = var.environment == "staging" ? digitalocean_kubernetes_cluster.doks[0].kube_config[0].token : (
            var.environment == "prod" ? data.aws_eks_cluster_auth.eks[0].token : "")
}

data "aws_eks_cluster_auth" "eks" {
  count = var.environment == "prod" ? 1 : 0
  name  = aws_eks_cluster.eks[0].name
}