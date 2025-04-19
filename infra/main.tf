# Terraform configuration for Kubernetes with Envoy Proxy

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.region
}

# Kubernetes and Helm Providers (configured after EKS creation)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Variables
variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "envoy-gateway-cluster"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "envoy-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Self-signed TLS Certificate for Testing
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem
  subject {
    common_name  = "example.com"
    organization = "Example, Inc"
  }
  validity_period_hours = 8760
  allowed_uses          = ["cert_signing", "crl_signing"]
  is_ca_certificate     = true
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem
  subject {
    common_name  = "www.example.com"
    organization = "Example, Inc"
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

# Kubernetes Secret for TLS Certificate
resource "kubernetes_secret" "tls_secret" {
  metadata {
    name      = "tls-secret"
    namespace = "default"
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.server.cert_pem
    "tls.key" = tls_private_key.server.private_key_pem
  }

  type = "kubernetes.io/tls"
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

  depends_on = [module.eks]
}

# Sample Backend Application
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = "default"
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "backend"
      }
    }
    template {
      metadata {
        labels = {
          app = "backend"
        }
      }
      spec {
        container {
          name  = "backend"
          image = "hashicorp/http-echo:0.2.3"
          args  = ["-text=Hello from backend"]
          port {
            container_port = 5678
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = "default"
  }
  spec {
    selector = {
      app = "backend"
    }
    port {
      port        = 5678
      target_port = 5678
    }
    type = "ClusterIP"
  }
}

# Envoy Gateway Configuration
resource "kubernetes_manifest" "gateway_class" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "envoy-gateway"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  }
}

resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "eg"
      namespace = "default"
    }
    spec = {
      gatewayClassName = "envoy-gateway"
      listeners = [
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind      = "Secret"
                name      = "tls-secret"
                namespace = "default"
              }
            ]
          }
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "backend-route"
      namespace = "default"
    }
    spec = {
      parentRefs = [
        {
          name      = "eg"
          namespace = "default"
        }
      ]
      hostnames = ["www.example.com"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "backend"
              port = 5678
            }
          ]
        }
      ]
    }
  }
}

# Load Balancing Policy
resource "kubernetes_manifest" "backend_traffic_policy" {
  manifest = {
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "BackendTrafficPolicy"
    metadata = {
      name      = "load-balance-policy"
      namespace = "default"
    }
    spec = {
      targetRefs = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "HTTPRoute"
          name  = "backend-route"
        }
      ]
      loadBalancer = {
        type = "RoundRobin"
      }
    }
  }
}

# Security Policy (JWT Authentication)
resource "kubernetes_manifest" "security_policy" {
  manifest = {
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "SecurityPolicy"
    metadata = {
      name      = "jwt-auth"
      namespace = "default"
    }
    spec = {
      targetRefs = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "HTTPRoute"
          name  = "backend-route"
        }
      ]
      jwt = {
        providers = [
          {
            name = "example"
            issuer = "https://example.com"
            jwks = {
              remote = {
                url = "https://example.com/.well-known/jwks.json"
              }
            }
          }
        ]
      }
    }
  }
}

# Output EKS Cluster Details
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}
