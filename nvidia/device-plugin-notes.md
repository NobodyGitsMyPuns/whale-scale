# NVIDIA Device Plugin for Kubernetes

The NVIDIA device plugin for Kubernetes is a DaemonSet that allows you to automatically:
- Expose the number of GPUs on each node of your cluster.
- Monitor and manage the lifecycle of GPUs.

## Installation Options

### Option 1: Direct Installation via kubectl

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
```

### Option 2: Using Helm Chart

```bash
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm install --generate-name nvdp/nvidia-device-plugin
```

### Option 3: NVIDIA GPU Operator (Recommended for Production)

The GPU Operator manages all components needed for GPU support in Kubernetes:

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm install --generate-name nvidia/gpu-operator
```

## Verifying Installation

Check that the plugin is installed:

```bash
kubectl get pods -n kube-system | grep nvidia-device-plugin
```

Verify GPU availability:

```bash
kubectl describe nodes | grep -i nvidia
```

## Setup for Different Environments

### Docker Desktop with WSL2

1. Install NVIDIA CUDA drivers in Windows
2. Install NVIDIA Container Toolkit in WSL2:

```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

3. Configure Docker:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Minikube

Start minikube with NVIDIA GPU support:

```bash
minikube start --driver=docker --container-runtime=docker --feature-gates=DevicePlugins=true
```

Then install the device plugin as described above.

### Cloud Providers

#### EKS (AWS)

Create a GPU-enabled node group:

```bash
eksctl create nodegroup \
  --cluster=your-cluster-name \
  --region=your-region \
  --name=gpu-nodes \
  --node-type=g4dn.xlarge \
  --nodes=1 \
  --nodes-min=1 \
  --nodes-max=3 \
  --managed
```

#### GKE (Google Cloud)

```bash
gcloud container clusters create your-cluster-name \
  --accelerator type=nvidia-tesla-t4,count=1 \
  --zone us-central1-a \
  --num-nodes=1
```

#### AKS (Azure)

```bash
az aks create \
  --resource-group your-resource-group \
  --name your-cluster-name \
  --node-vm-size Standard_NC6s_v3 \
  --node-count 1
```

## Testing GPU Support

Run a simple CUDA test pod:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cuda-test
spec:
  containers:
    - name: cuda-test
      image: nvidia/cuda:11.8.0-base-ubuntu22.04
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
  restartPolicy: Never
EOF
```

Check the logs:

```bash
kubectl logs cuda-test
```