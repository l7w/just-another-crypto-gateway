output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = var.environment == "dev" ? "https://localhost:8443" : (var.provider == "aws" ? (length(module.eks) > 0 ? module.eks[0].cluster_endpoint : null) : (var.provider == "azure" ? (length(module.aks) > 0 ? module.aks[0].kube_config.0.host : null) : (var.provider == "digitalocean" ? (length(digitalocean_kubernetes_cluster.doks) > 0 ? digitalocean_kubernetes_cluster.doks[0].endpoint : null) : null)))
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "kubectl_command" {
  description = "Command to configure kubectl"
  value       = var.environment == "dev" ? "kubectl config use-context kind-${var.cluster_name}" : (var.provider == "aws" ? "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}" : (var.provider == "azure" ? "az aks get-credentials --resource-group ${var.cluster_name}-rg --name ${var.cluster_name}" : (var.provider == "digitalocean" ? "doctl kubernetes cluster kubeconfig save ${var.cluster_name}" : "")))
}
