# Terraform configuration for Kubernetes with Envoy Proxy (Local Docker for Dev, Cloud for Prod)

provider "kubernetes" {
 config_path = "~/.kube/config"  # Path to the kubeconfig file
}

# Local KIND Cluster Setup for Dev
resource "null_resource" "kind_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      kind create cluster --name ${var.cluster_name} --config kind-config.yaml || true
      kubectl config use-context kind-${var.cluster_name}
    EOT
  }
}

# Helm Release for Envoy Gateway
resource "helm_release" "envoy_gateway" {
  name       = "envoy-gateway"
  repository = "https://helm.envoyproxy.io"
  chart      = "gateway-helm"
  namespace  = "default"
  version    = "v0.6.0"

  set {
    name  = "gateway.controllerName"
    value = "gateway.envoyproxy.io/gatewayclass-controller"
  }

  depends_on = [
    null_resource.kind_cluster
  ]
}

# Payment Gateway Deployment
resource "kubernetes_deployment" "payment_gateway" {
  metadata {
    name      = "payment-gateway"
    namespace = "default"
    labels = {
      app = "payment-gateway"
    }
  }
  spec {
    replicas = 3
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
          name  = "payment-gateway"
          image = "payment-gateway:latest"
          env {
            name  = "TWILIO_SID"
            value = var.twilio_sid
          }
          env {
            name  = "TWILIO_AUTH_TOKEN"
            value = var.twilio_auth_token
          }
          env {
            name  = "TWILIO_PHONE"
            value = var.twilio_phone
          }
          env {
            name  = "TWILIO_WEBHOOK_SECRET"
            value = var.twilio_webhook_secret
          }
          env {
            name  = "MQTT_BROKER"
            value = var.mqtt_broker
          }
          env {
            name  = "MQTT_PORT"
            value = var.mqtt_port
          }
          env {
            name  = "MQTT_TOPIC"
            value = var.mqtt_topic
          }
          env {
            name  = "INFURA_URL"
            value = var.infura_url
          }
          env {
            name  = "WALLET_PRIVATE_KEY"
            value = var.wallet_private_key
          }
          env {
            name  = "RATE_LIMIT_CALLS"
            value = "10"
          }
          env {
            name  = "RATE_LIMIT_PERIOD"
            value = "60"
          }
          env {
            name  = "REDIS_URL"
            value = "redis://redis:6379"
          }
          env {
            name  = "FLASK_HOST"
            value = "0.0.0.0"
          }
          env {
            name  = "FLASK_PORT"
            value = "5000"
          }
          env {
            name  = "MAX_AMOUNT"
            value = "100.0"
          }
          env {
            name  = "ALLOWED_COMMANDS"
            value = "PAY,TRANSFER"
          }
        }
      }
    }
  }
}

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
      port        = 5000
      target_port = 5000
    }
    type = "ClusterIP"
  }
}

# Redis Deployment for Rate Limiting
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = "default"
    labels = {
      app = "redis"
    }
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
          name  = "redis"
          image = "redis:7-alpine"
          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

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

output "kubeconfig" {
  value = kubernetes_service.redis
  sensitive = true
}

output "endpoint" {
  value = kubernetes_deployment.payment_gateway
  sensitive = true
}

output "client_key" {
  value = kubernetes_service.payment_gateway
}