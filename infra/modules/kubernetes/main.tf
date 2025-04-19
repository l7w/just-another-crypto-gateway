resource "digitalocean_kubernetes_cluster" "doks" {
  count      = var.environment == "staging" ? 1 : 0
  name       = "crypto-gateway-staging"
  region     = "nyc1"
  version    = "1.29"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 3
  }
}

resource "aws_eks_cluster" "eks" {
  count    = var.environment == "prod" ? 1 : 0
  name     = "crypto-gateway-prod"
  role_arn = aws_iam_role.eks[0].arn
  version  = "1.29"

  vpc_config {
    subnet_ids = aws_subnet.eks.*.id
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.environment == "prod" ? 1 : 0
  name                = "crypto-gateway-prod"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group
  dns_prefix          = "crypto-gateway"
  kubernetes_version  = "1.29"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "google_container_cluster" "gke" {
  count    = var.environment == "prod" ? 1 : 0
  name     = "crypto-gateway-prod"
  location = var.gcp_region
  initial_node_count = 3
  min_master_version = "1.29"

  node_config {
    machine_type = "e2-medium"
  }
}

# Deployments
resource "kubernetes_deployment" "payment_gateway" {
  count = var.environment != "dev" ? 1 : 0
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

resource "kubernetes_deployment" "sip_gateway" {
  count = var.environment != "dev" ? 1 : 0
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

resource "kubernetes_deployment" "middleware" {
  count = var.environment != "dev" ? 1 : 0
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

# Services
resource "kubernetes_service" "payment_gateway" {
  count = var.environment != "dev" ? 1 : 0
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

resource "kubernetes_service" "sip_gateway" {
  count = var.environment != "dev" ? 1 : 0
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

resource "kubernetes_service" "middleware" {
  count = var.environment != "dev" ? 1 : 0
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

# AWS-specific resources
resource "aws_vpc" "eks" {
  count      = var.environment == "prod" ? 1 : 0
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "eks" {
  count             = var.environment == "prod" ? 2 : 0
  vpc_id            = aws_vpc.eks[0].id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
}

resource "aws_iam_role" "eks" {
  count = var.environment == "prod" ? 1 : 0
  name  = "crypto-gateway-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Outputs
output "cluster_endpoint" {
  value = var.environment == "staging" ? (length(digitalocean_kubernetes_cluster.doks) > 0 ? digitalocean_kubernetes_cluster.doks[0].endpoint : "") : (
    var.environment == "prod" ? (length(aws_eks_cluster.eks) > 0 ? aws_eks_cluster.eks[0].endpoint : (
      length(azurerm_kubernetes_cluster.aks) > 0 ? azurerm_kubernetes_cluster.aks[0].kube_config[0].host : (
        length(google_container_cluster.gke) > 0 ? google_container_cluster.gke[0].endpoint : ""
      )
    )) : ""
  )
}

output "cluster_ca_certificate" {
  value = var.environment == "staging" ? (length(digitalocean_kubernetes_cluster.doks) > 0 ? digitalocean_kubernetes_cluster.doks[0].cluster_ca_certificate : "") : (
    var.environment == "prod" ? (length(aws_eks_cluster.eks) > 0 ? aws_eks_cluster.eks[0].certificate_authority[0].data : (
      length(azurerm_kubernetes_cluster.aks) > 0 ? azurerm_kubernetes_cluster.aks[0].kube_config[0].cluster_ca_certificate : (
        length(google_container_cluster.gke) > 0 ? google_container_cluster.gke[0].master_auth[0].cluster_ca_certificate : ""
      )
    )) : ""
  )
}

output "cluster_token" {
  value = var.environment == "staging" ? (length(digitalocean_kubernetes_cluster.doks) > 0 ? data.digitalocean_kubernetes_cluster.doks[0].kube_config[0].token : "") : (
    var.environment == "prod" ? (length(aws_eks_cluster.eks) > 0 ? data.aws_eks_cluster_auth.eks[0].token : (
      length(azurerm_kubernetes_cluster.aks) > 0 ? azurerm_kubernetes_cluster.aks[0].kube_config[0].token : (
        length(google_container_cluster.gke) > 0 ? data.google_container_cluster.gke[0].master_auth[0].token : ""
      )
    )) : ""
  )
}