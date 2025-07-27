# Hello World Temporal App with Kubernetes and NVIDIA GPU Support

This repository contains a Hello World application built with Temporal.io and Python, designed to run on Kubernetes with NVIDIA GPU acceleration. It demonstrates best practices for workflow development, task queues, retries, heartbeats, signals, and graceful shutdown.

## Prerequisites

- Docker and Docker Compose
- Python 3.7+
- Kubernetes cluster (Docker Desktop with WSL2, minikube, or cloud provider)
- NVIDIA GPU (for GPU acceleration) - Optional
- NVIDIA Container Toolkit (for Docker GPU support) - Optional
- NVIDIA Device Plugin (for Kubernetes GPU support) - Optional

## Quick Start

### Clone the Repository

```bash
git clone https://github.com/jeric/whale-scale.git
cd whale-scale
```

### Install Dependencies

#### Option 1: Using Make (Recommended)

```bash
make install
```

This will:
- Install Python virtual environment tools
- Create and activate a virtual environment
- Install all Python dependencies
- Install Temporal CLI

#### Option 2: Manual Installation

##### Ubuntu/Debian

```bash
# Install Python virtual environment tools
sudo apt update
sudo apt install -y python3-venv python3-pip

# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install Temporal CLI
curl -sSf https://temporal.download/cli.sh | sh
export PATH="$PATH:/home/jeric/.temporalio/bin"
```

##### macOS

```bash
# Install Python (if not already installed)
brew install python

# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install Temporal CLI
curl -sSf https://temporal.download/cli.sh | sh
export PATH="$PATH:/home/jeric/.temporalio/bin"
```

##### Windows (PowerShell)

```powershell
# Create virtual environment
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Install Temporal CLI (requires WSL or Git Bash)
curl -sSf https://temporal.download/cli.sh | sh
```

##### Windows (WSL2)

```bash
# Install Python virtual environment tools
sudo apt update
sudo apt install -y python3-venv python3-pip

# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install Temporal CLI
curl -sSf https://temporal.download/cli.sh | sh
export PATH="$PATH:/home/jeric/.temporalio/bin"
```

### Start Temporal Server

```bash
# Start the Temporal development server
/home/jeric/.temporalio/bin/temporal server start-dev
```

This starts:
- Temporal Server on `localhost:7233`
- Web UI on `http://localhost:8233`
- Metrics on `http://localhost:41949/metrics`

### Run the Worker

In a new terminal window:

```bash
# Activate virtual environment
source .venv/bin/activate

# Run the worker
make dev
```

### Start a Workflow

In another terminal window:

```bash
# Activate virtual environment
source .venv/bin/activate

# Start a workflow
make start-workflow
```

### View the Web UI

Open [http://localhost:8233](http://localhost:8233) in your browser to see the Temporal Web UI.

## Project Structure

- `app/workflows.py` - Workflow definitions with signal and query capabilities
- `app/activities.py` - Activity definitions with retry and heartbeat examples
- `app/worker.py` - Worker implementation with graceful shutdown
- `app/starter.py` - CLI to start workflows, send signals, and query results
- `app/tests/` - Unit tests using the Temporal test environment
- `k8s/` - Kubernetes manifests for deploying to a cluster
- `nvidia/` - Documentation for setting up NVIDIA GPU support

## Available Make Commands

```bash
# Installation and setup
make install          # Install all dependencies and Temporal CLI

# Development
make dev              # Run the worker locally
make start-workflow   # Start a sample workflow
make test             # Run tests

# Docker
make build            # Build Docker image
make up               # Start services with Docker Compose
make down             # Stop services

# Kubernetes
make kubectl-apply    # Deploy to Kubernetes
make submit           # Submit workflow job to Kubernetes
make logs             # View Kubernetes logs

# GPU Setup
make setup-nvidia-docker  # Setup NVIDIA Container Toolkit
make setup-nvidia-k8s     # Install NVIDIA Device Plugin

# Cleanup
make clean            # Clean up Docker resources
```

## Running on Kubernetes

### Prerequisites

1. **Install minikube** (for local development):
   ```bash
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   ```

2. **Start minikube cluster**:
   ```bash
   minikube start --driver=docker
   ```

3. **Build and load Docker image**:
   ```bash
   make build
   eval $(minikube docker-env) && docker build . -f Dockerfile.worker -t whale-scale:latest
   ```

### Install NVIDIA Device Plugin

```bash
make setup-nvidia-k8s
```

### Deploy to Kubernetes

```bash
make kubectl-apply
```

### Submit a Workflow

```bash
make submit
```

### View Logs

```bash
make logs
```

### Important Notes for Kubernetes

- The Kubernetes deployment requires a Temporal server running in the cluster
- For local development with minikube, you may need to install Temporal server separately
- The current manifests are configured for local development without GPU requirements
- For production deployment, update the image references and add GPU requirements

## GPU Support

This project is configured to use NVIDIA GPUs both in Docker and Kubernetes:

- The Docker Compose file includes GPU device configuration
- The Kubernetes deployment requests GPU resources
- The worker Dockerfile uses an NVIDIA CUDA base image

For detailed instructions on setting up GPU support, see the `nvidia/device-plugin-notes.md` file.

## Scaling to Cloud

### Amazon EKS

1. Create an ECR repository and authenticate:
   ```bash
   aws ecr create-repository --repository-name whale-scale
   aws ecr get-login-password | docker login --username AWS --password-stdin <your-aws-account>.dkr.ecr.<region>.amazonaws.com
   ```

2. Build and push the image:
   ```bash
   docker build -t <your-aws-account>.dkr.ecr.<region>.amazonaws.com/whale-scale:latest -f Dockerfile.worker .
   docker push <your-aws-account>.dkr.ecr.<region>.amazonaws.com/whale-scale:latest
   ```

3. Update the image in `k8s/deployment-worker.yaml` and apply:
   ```bash
   kubectl apply -f k8s/
   ```

### Google GKE and Azure AKS

Similar steps apply for GKE and AKS. See cloud-specific instructions in `nvidia/device-plugin-notes.md`.

## Migrating to Temporal Cloud

To migrate to Temporal Cloud:

1. Create a namespace in Temporal Cloud
2. Update the `TEMPORAL_TARGET` environment variable to point to your Temporal Cloud endpoint
3. Add authentication credentials
4. Deploy your workers

For more information, see the [Temporal Cloud documentation](https://docs.temporal.io/cloud).

## Troubleshooting

### Worker Can't Reach Server

- Ensure the Temporal server is running: Check if `temporal server start-dev` is running
- Verify the server is accessible: `curl http://localhost:7233/health`
- Check that `TEMPORAL_TARGET` is set correctly

### No GPUs Discovered

- Verify NVIDIA drivers are installed: `nvidia-smi`
- Check NVIDIA Container Toolkit is configured: `docker run --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi`
- In Kubernetes, check device plugin is running: `kubectl get pods -n kube-system | grep nvidia-device-plugin`

### WSL2 CUDA Not Visible

1. Ensure NVIDIA drivers are installed in Windows
2. Configure WSL2 to use the Windows NVIDIA drivers
3. Install NVIDIA Container Toolkit in WSL2
4. Restart Docker in WSL2

### Python Dependency Issues

If you see `ModuleNotFoundError: No module named 'temporalio'` or similar errors:

1. Make sure you've activated your virtual environment:
   ```bash
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```
2. Verify dependencies are installed:
   ```bash
   pip list | grep temporalio
   ```
3. If missing, reinstall dependencies:
   ```bash
   make install
   ```
4. For system Python issues on Ubuntu/Debian (externally-managed-environment error):
   ```bash
   # Always use a virtual environment instead of system Python
   make install
   ```

### Temporal Server Issues

- If the Temporal server fails to start, ensure you have the latest Temporal CLI:
  ```bash
  curl -sSf https://temporal.download/cli.sh | sh
  ```
- Check if port 7233 is already in use: `netstat -tulpn | grep 7233`
- Restart the Temporal server: `pkill temporal` then `temporal server start-dev`

### Kubernetes Issues

- **No cluster found**: Install and start minikube: `minikube start --driver=docker`
- **Image pull errors**: Build image in minikube context: `eval $(minikube docker-env) && docker build . -f Dockerfile.worker -t whale-scale:latest`
- **Pod crashes**: Check logs: `kubectl logs -n temporal <pod-name>`
- **Temporal server not found**: Install Temporal server in the cluster or use external endpoint

## Example Output

When everything is working correctly, you should see:

```
# Terminal 1 - Temporal Server
CLI 1.4.1 (Server 1.28.0, UI 2.39.0)
Server:  localhost:7233
UI:      http://localhost:8233
Metrics: http://localhost:41949/metrics

# Terminal 2 - Worker
uvloop not available, using standard event loop
Connecting to Temporal server at localhost:7233
Using task queue: hello-python-tq
Starting worker...

# Terminal 3 - Workflow
Workflow result: Hello, Jesse!
```

## References

- [Temporal Python SDK Documentation](https://python.temporal.io/)
- [Temporal Core Concepts](https://docs.temporal.io/concepts)
- [Temporal CLI Documentation](https://docs.temporal.io/cli)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html)
- [NVIDIA Device Plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)


