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

# Redis Deployment
resource "kubernetes_deployment" "redis" {
  count = var.environment == "dev" ? 1 : 0
  metadata {
    name      = "redis"
    namespace = "default"
  }
  spec {
    replicas = 1
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
  count = var.environment == "dev" ? 1 : 0
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
  count = var.environment == "dev" ? 1 : 0
  metadata {
    name      = "postgres"
    namespace = "default"
  }
  spec {
    replicas = 1
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
  count = var.environment == "dev" ? 1 : 0
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
  count = var.environment == "dev" ? 1 : 0
  metadata {
    name      = "payment-gateway"
    namespace = "default"
  }
  spec {
    replicas = 1
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
  count = var.environment == "dev" ? 1 : 0
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
    type = "ClusterIP"
  }
}

# SIP Gateway Deployment
resource "kubernetes_deployment" "sip_gateway" {
  count = var.environment == "dev" ? 1 : 0
  metadata {
    name      = "sip-gateway"
    namespace = "default"
  }
  spec {
    replicas = 1
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
  count = var.environment == "dev" ? 1 : 0
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
    type = "ClusterIP"
  }
}

# Middleware Deployment
resource "kubernetes_deployment" "middleware" {
  count = var.environment == "dev" ? 1 : 0
  metadata {
    name      = "middleware"
    namespace = "default"
  }
  spec {
    replicas = 1
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
  count = var.environment == "dev" ? 1 : 0
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
    type = "ClusterIP"
  }
}

# Outputs (used in monitoring module)
output "cluster_endpoint" {
  value = var.environment == "dev" ? "https://127.0.0.1:8443" : "" # Minikube default
}

output "cluster_ca_certificate" {
  value = var.environment == "dev" ? "" : ""
}

output "cluster_token" {
  value = var.environment == "dev" ? "" : ""
}