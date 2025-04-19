output "kubernetes_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
}

output "nomad_address" {
  description = "Nomad server address"
  value       = var.nomad_address
}

output "prometheus_url" {
  description = "Prometheus service URL"
  value       = terraform.workspace != "dev" ? "http://${kubernetes_service.prometheus[0].metadata[0].name}:9090" : "http://localhost:9090"
}

output "grafana_url" {
  description = "Grafana service URL"
  value       = terraform.workspace != "dev" ? "http://${kubernetes_service.grafana[0].metadata[0].name}:3000" : "http://localhost:3001"
}