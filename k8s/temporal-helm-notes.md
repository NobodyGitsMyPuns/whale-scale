# Installing Temporal Server with Helm

This document provides instructions for installing Temporal Server in a Kubernetes cluster using the official Helm chart.

## Prerequisites

- Kubernetes cluster (minikube, Docker Desktop with Kubernetes, or cloud provider)
- Helm v3.x installed
- kubectl configured to access your cluster

## Installation Steps

1. Add the Temporal Helm repository:

```bash
helm repo add temporal https://temporal.github.io/helm-charts/
helm repo update
```

2. Create a namespace for Temporal (if not already created):

```bash
kubectl create namespace temporal
```

3. Install Temporal with default configuration:

```bash
helm install temporal temporal/temporal --namespace temporal
```

4. For a production setup with custom values, create a `values.yaml` file and install with:

```bash
helm install temporal temporal/temporal --namespace temporal -f values.yaml
```

## Example values.yaml for Production

```yaml
server:
  replicaCount: 3
  
persistence:
  enabled: true
  storageClass: "standard"
  
cassandra:
  enabled: false # Set to true if using Cassandra

postgresql:
  enabled: true
  persistence:
    size: 10Gi
    
elasticsearch:
  enabled: true # For advanced visibility features
```

## Accessing Temporal

After installation, you can access the Temporal frontend service at:

```
temporal-frontend.temporal.svc.cluster.local:7233
```

For the Web UI, you can port-forward:

```bash
kubectl port-forward svc/temporal-web 8080:8080 -n temporal
```

Then access the Web UI at http://localhost:8080

## Upgrading

To upgrade your Temporal installation:

```bash
helm repo update
helm upgrade temporal temporal/temporal --namespace temporal
``` 