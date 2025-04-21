#!/bin/bash
# kind delete cluster -n envoy-gateway-cluster 

# Install KIND if not present
if ! command -v kind &> /dev/null; then
  echo "Installing KIND..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
fi

# Build and load Docker image into KIND
echo "Building payment-gateway image..."
docker build -t payment-gateway:latest .
kind load docker-image payment-gateway:latest --name ${CLUSTER_NAME:-envoy-gateway-cluster}

# Create KIND cluster
#echo "Creating KIND cluster..."
#kind create cluster --name ${CLUSTER_NAME:-envoy-gateway-cluster} --config kind-config.yaml

# Verify cluster
kubectl cluster-info
kubectl get nodes

# curl --cacert ca.crt https://localhost:8443/sms -H "Authorization: Bearer <jwt_token>" -d '{"From":"+1234567890","Body":"PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"}' -H "Content-Type: application/json"