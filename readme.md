# Whale Scale Temporal App with GPU-Powered Image Generation

This repository contains a comprehensive Temporal.io application built with Python, featuring multiple workflow types designed to run on Kubernetes with NVIDIA GPU acceleration. It includes a **GPU-powered image generation microservice** that runs Stable Diffusion models locally and can scale to the cloud.

## 🎨 GPU-Powered Image Generation

The application now includes a **real image generation microservice** that:

- **Runs Stable Diffusion models on your local GPU** (no more simulated generation!)
- **Supports multiple models** (stable-diffusion-v1-5, SDXL, custom .safetensors, .ckpt files)
- **Scales to cloud** with the same microservice architecture
- **Provides REST API** for image generation with progress tracking
- **Integrates seamlessly** with Temporal workflows
- **Achieves 99%+ GPU utilization** with large models like SDXL

## 🚀 GPU Utilization Optimization

**Key Finding**: The RTX 4090 is so powerful that smaller models (like SD 1.5) don't stress it enough to show high utilization. To achieve 99%+ GPU utilization:

- **Use SDXL models** (`stabilityai/stable-diffusion-xl-base-1.0`) instead of SD 1.5
- **Higher resolutions** (1024x1024 vs 512x512)
- **More inference steps** (50 vs 20-30)
- **Float32 precision** (disables some optimizations for higher utilization)

**Expected GPU metrics with SDXL**:
- **GPU Utilization**: 99-100%
- **Power Usage**: 430-440W (out of 441W max)
- **Memory Usage**: 17-22GB (out of 24GB)
- **Temperature**: 70-75°C

## 🔧 Recent Fixes & Improvements

### Temporal Workflow Sandbox Issues
- **Fixed**: `RestrictedWorkflowAccessError` by configuring `SandboxRestriction.UNRESTRICTED`
- **Fixed**: Missing dependencies (`aiofiles`, `aiohttp`, `torch`) in virtual environment
- **Fixed**: PyTorch security restrictions for .ckpt files using `torch.serialization.safe_globals`

### Dependency Management
- **Added**: Complete dependency installation for both main app and image service
- **Fixed**: Virtual environment activation in all Makefile commands
- **Added**: GPU monitoring and testing commands

## Workflow Types

This application includes three different workflow types:

1. **HelloWorkflow** - Simple greeting workflow with signals and queries
2. **HealthCheckWorkflow** - Container health monitoring workflow
3. **Text2ImageWorkflow** - **Real AI-powered text-to-image generation workflow** 🎨

## Prerequisites

- Docker and Docker Compose
- Python 3.7+
- **NVIDIA GPU with CUDA support** (for image generation)
- **NVIDIA Container Toolkit** (for Docker GPU support)
- Kubernetes cluster (Docker Desktop with WSL2, minikube, or cloud provider) - Optional
- NVIDIA Device Plugin (for Kubernetes GPU support) - Optional

## Quick Start

### Clone the Repository

```bash
git clone https://github.com/jeric/whale-scale.git
cd whale-scale
```

### Easy Setup (Recommended)

```bash
# Install all dependencies including image generation service
make install

# Start all services (Temporal server, image service, and worker)
make start-all
```

This will:
- Install all Python dependencies including image generation requirements
- Start the Temporal server
- Start the image generation service
- Start the Temporal worker
- Provide GPU monitoring capabilities

### Manual Setup

#### Install Dependencies

```bash
make install
```

#### Start Services

```bash
# Start Temporal server
make start-temporal

# In another terminal, start image generation service
make start-image-service

# In another terminal, start the worker
make dev
```

#### Generate Images with High GPU Utilization

```bash
# Generate with SDXL for maximum GPU utilization (99%+)
make start-text2image-sdxl

# Generate with SD 1.5 at high resolution
make start-text2image-high-util

# Monitor GPU usage in real-time
make gpu-monitor
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Temporal Workflow Sandbox Errors
**Error**: `RestrictedWorkflowAccessError: Cannot access os.stat.__call__ from inside a workflow`

**Solution**: The worker is now configured with `SandboxRestriction.UNRESTRICTED` to avoid sandbox restrictions.

#### 2. Missing Dependencies
**Error**: `ModuleNotFoundError: No module named 'torch'` or `'aiofiles'` or `'aiohttp'`

**Solution**: Run `make install` to install all dependencies in the virtual environment.

#### 3. Low GPU Utilization
**Issue**: GPU shows only 2-3% utilization with SD 1.5

**Solution**: Use SDXL models or higher resolution settings:
```bash
make start-text2image-sdxl
```

#### 4. PyTorch Security Restrictions
**Error**: `WeightsUnpickler error: Unsupported global: GLOBAL pytorch_lightning.callbacks.model_checkpoint.ModelCheckpoint`

**Solution**: The image service now uses `torch.serialization.safe_globals` to handle .ckpt files.

### Service Status Commands

```bash
# Check if services are running
ps aux | grep -E "(image_generation_service|app.worker)"

# View Temporal workflows
make temporal-list

# Monitor GPU usage
make gpu-monitor

# Test GPU directly
make gpu-test
```

## 📊 Monitoring & Management

### Temporal Web UI
Access the Temporal Web UI at: http://localhost:8233

### GPU Monitoring
```bash
# Real-time GPU monitoring
make gpu-monitor

# Test GPU with simple operations
make gpu-test

# List available models
make list-models
```

### Workflow Management
```bash
# List all workflows
make temporal-list

# Describe specific workflow
make temporal-describe WORKFLOW_ID=your-workflow-id

# View task queue statistics
make temporal-task-queue
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Temporal      │    ┌──────────────────┐    │   Your Local    │
│   Workflow      │───▶│   Image Gen      │───▶│   GPU Models    │
│                 │    │   Microservice   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Generated     │    │   Progress       │    │   Real Images   │
│   Images        │    │   Tracking       │    │   on GPU        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Workflow Details

### HelloWorkflow

A simple greeting workflow that demonstrates basic Temporal concepts:

```bash
# Start a hello workflow
make start-workflow

# With custom workflow ID
python3 -m app.starter --type hello --name "Jesse" --id "my-hello-workflow"
```

**Features:**
- Basic workflow execution
- Signal handling (`set_suffix`)
- Query support (`get_state`)
- Activity integration with heartbeat

### HealthCheckWorkflow

Monitors the health of Docker containers:

```bash
# Check health of specific containers
make start-health-check

# With custom workflow ID
python3 -m app.starter --type health_check --containers whale-scale-worker-1 --id "health-check-001"
```

**Features:**
- Parallel container health checking
- Real-time health status monitoring
- Signal to add containers dynamically
- Query to get health summary
- Error handling for missing containers

**Health Status Types:**
- `healthy` - Container is running and healthy
- `unhealthy` - Container is running but health check failed
- `stopped` - Container is stopped but exited cleanly
- `error` - Container not found or other error

### Text2ImageWorkflow 🎨

**Generates real images from text prompts using your local GPU models:**

```bash
# Generate with SDXL for maximum GPU utilization
make start-text2image-sdxl

# Generate with SD 1.5 at high resolution
make start-text2image-high-util

# Generate with custom parameters
python3 -m app.starter --type text2image \
  --prompt "Cyberpunk city at night, neon lights, rain" \
  --blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, nsfw, grainy, noisy, overexposed, underexposed
 \
  --model "stabilityai/stable-diffusion-xl-base-1.0" \
  --width 1024 --height 1024 \
  --steps 50 --cfg-scale 15.0 \
  --seed 42
```

**Features:**
- **Real GPU-powered image generation** (no simulation!)
- Support for multiple AI models
- **Progress tracking** during generation
- **Signal to update progress** or cancel generation
- **Query to get current status**
- **Metadata tracking** (generation time, model version, etc.)
- **Base64 image data** in response for immediate use

**Supported Models:**
- `stabilityai/stable-diffusion-xl-base-1.0` (SDXL - **99%+ GPU utilization**)
- `runwayml/stable-diffusion-v1-5` (SD 1.5 - moderate utilization)
- Any HuggingFace model directory
- Custom `.safetensors` files
- Custom `.ckpt` files

**Generation Parameters:**
- `--prompt` - Text description of desired image
- `--negative-prompt` - What to avoid in the image
- `--model` - Model name or path
- `--width/--height` - Image dimensions (512-1024)
- `--steps` - Number of inference steps (10-50)
- `--cfg-scale` - Guidance scale (1.0-20.0)
- `--seed` - Random seed for reproducible results

## Image Generation Microservice

The image generation service runs as a separate microservice with these endpoints:

```bash
# Health check
curl http://localhost:8000/

# List available models
curl http://localhost:8000/models

# Generate an image with SDXL for high GPU utilization
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A majestic whale swimming in the deep ocean, highly detailed, 8k resolution",
    "model": "stabilityai/stable-diffusion-xl-base-1.0",
    "width": 1024,
    "height": 1024,
    "steps": 50,
    "cfg_scale": 15.0
  }'

# Check generation status
curl http://localhost:8000/status/{task_id}

# Get generated image
curl http://localhost:8000/result/{task_id}
```

## Project Structure

- `app/workflows.py` - Workflow definitions with signal and query capabilities
- `app/activities.py` - Activity definitions with real GPU image generation
- `app/worker.py` - Worker implementation with graceful shutdown
- `app/starter.py` - CLI to start workflows, send signals, and query results
- `app/tests/` - Unit tests using the Temporal test environment
- `image_generation_service.py` - **GPU-powered image generation microservice**
- `Dockerfile.image-service` - Docker image for the microservice
- `image-service-requirements.txt` - Dependencies for image generation
- `setup-models.sh` - **Automated setup script**
- `k8s/` - Kubernetes manifests for deploying to a cluster
- `nvidia/` - Documentation for setting up NVIDIA GPU support

## Available Make Commands

```bash
# Installation and setup
make install              # Install all dependencies and Temporal CLI

# Service management
make start-all            # Start all services (Temporal, image service, worker)
make start-temporal       # Start Temporal server only
make start-image-service  # Start image generation service only
make dev                  # Run the worker locally

# Workflow commands
make start-workflow       # Start a hello workflow
make start-health-check   # Start a health check workflow
make start-text2image     # Start a text-to-image workflow
make start-text2image-sdxl # Start SDXL workflow for high GPU utilization
make start-text2image-high-util # Start high-utilization SD 1.5 workflow

# GPU monitoring and testing
make gpu-monitor          # Monitor GPU utilization with nvidia-smi
make gpu-test             # Test GPU with PyTorch
make test-sdxl            # Test SDXL generation via API
make test-multi-gen       # Test multiple simultaneous generations

# Docker
make build                # Build worker Docker image
make build-image-service  # Build image generation service
make up                   # Start services with Docker Compose
make down                 # Stop services

# Kubernetes
make kubectl-apply        # Deploy to Kubernetes
make submit               # Submit workflow job to Kubernetes
make logs                 # View Kubernetes logs

# GPU Setup
make setup-nvidia-docker  # Setup NVIDIA Container Toolkit
make setup-nvidia-k8s     # Install NVIDIA Device Plugin

# Utilities
make list-models          # List available models in ComfyUI directory
make test                 # Run tests
make clean                # Clean up all resources
```

## GPU Utilization Guide

### Achieving High GPU Utilization

The RTX 4090 is extremely powerful, so achieving high utilization requires specific configurations:

**For 99%+ GPU utilization:**
```bash
# Use SDXL model with high resolution and many steps
make start-text2image-sdxl
```

**Expected metrics:**
- GPU Utilization: 99-100%
- Power Usage: 430-440W
- Memory Usage: 17-22GB
- Temperature: 70-75°C

**For moderate utilization (50-80%):**
```bash
# Use SD 1.5 with high resolution
make start-text2image-high-util
```

**For low utilization (2-10%):**
```bash
# Use SD 1.5 with default settings
make start-text2image
```

### Monitoring GPU Usage

```bash
# Real-time monitoring
make gpu-monitor

# Quick GPU test
make gpu-test

# Test multiple generations simultaneously
make test-multi-gen
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

3. **Build and load Docker images**:
   ```bash
   make build
   make build-image-service
   eval $(minikube docker-env) && docker build . -f Dockerfile.worker -t whale-scale:latest
   eval $(minikube docker-env) && docker build . -f Dockerfile.image-service -t whale-scale-image-service:latest
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
- **The image generation service requires GPU nodes** in production

## GPU Support

This project is configured to use NVIDIA GPUs both in Docker and Kubernetes:

- The Docker Compose file includes GPU device configuration
- The Kubernetes deployment requests GPU resources
- The worker Dockerfile uses an NVIDIA CUDA base image
- **The image generation service runs models directly on GPU**

For detailed instructions on setting up GPU support, see the `nvidia/device-plugin-notes.md` file.

## Scaling to Cloud

### Amazon EKS

1. Create an ECR repository and authenticate:
   ```bash
   aws ecr create-repository --repository-name whale-scale
   aws ecr get-login-password | docker login --username AWS --password-stdin <your-aws-account>.dkr.ecr.<region>.amazonaws.com
   ```

2. Build and push the images:
   ```bash
   docker build -t <your-aws-account>.dkr.ecr.<region>.amazonaws.com/whale-scale:latest -f Dockerfile.worker .
   docker build -t <your-aws-account>.dkr.ecr.<region>.amazonaws.com/whale-scale-image-service:latest -f Dockerfile.image-service .
   docker push <your-aws-account>.dkr.ecr.<region>.amazonaws.com/whale-scale:latest
   docker push <your-aws-account>.dkr.ecr.<region>.amazonaws.com/whale-scale-image-service:latest
   ```

3. Update the images in `k8s/deployment-worker.yaml` and apply:
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
4. Deploy your workers and image generation service

For more information, see the [Temporal Cloud documentation](https://docs.temporal.io/cloud).

## References

- [Temporal Python SDK Documentation](https://python.temporal.io/)
- [Temporal Core Concepts](https://docs.temporal.io/concepts)
- [Temporal CLI Documentation](https://docs.temporal.io/cli)
- [Stable Diffusion Documentation](https://huggingface.co/docs/diffusers/index)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html)
- [NVIDIA Device Plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)


