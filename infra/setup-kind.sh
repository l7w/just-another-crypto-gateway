#!/bin/bash

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
echo "Creating KIND cluster..."
kind create cluster --name ${CLUSTER_NAME:-envoy-gateway-cluster} --config kind-config.yaml

# Verify cluster
kubectl cluster-info
kubectl get nodes
