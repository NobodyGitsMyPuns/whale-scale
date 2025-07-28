# Installation and setup
install:
	@echo "Installing dependencies..."
	@echo "Installing Python virtual environment tools..."
	sudo apt update && sudo apt install -y python3-venv python3-pip || echo "Skipping apt install (not Ubuntu/Debian)"
	@echo "Creating virtual environment..."
	rm -rf /tmp/whale-scale-venv || true
	python3 -m venv /tmp/whale-scale-venv
	chmod +w /tmp/whale-scale-venv/bin/activate.csh || true
	@echo "Activating virtual environment and installing Python dependencies..."
	. /tmp/whale-scale-venv/bin/activate && pip install -r requirements.txt
	@echo "Installing image generation service dependencies..."
	. /tmp/whale-scale-venv/bin/activate && pip install -r image-service-requirements.txt
	@echo "Installing additional dependencies (aiofiles, aiohttp, torch)..."
	. /tmp/whale-scale-venv/bin/activate && pip install aiofiles aiohttp
	. /tmp/whale-scale-venv/bin/activate && pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
	@echo "Installing Temporal CLI..."
	curl -sSf https://temporal.download/cli.sh | sh
	@echo "Installation complete!"
	@echo "To activate the virtual environment, run: source /tmp/whale-scale-venv/bin/activate"
	@echo "To add Temporal CLI to PATH, run: export PATH=\"\$$PATH:/home/jeric/.temporalio/bin\""

# Fix common issues
fix-dependencies:
	@echo "Installing missing dependencies..."
	. /tmp/whale-scale-venv/bin/activate && pip install aiofiles aiohttp
	. /tmp/whale-scale-venv/bin/activate && pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
	@echo "Dependencies installed!"

fix-sandbox:
	@echo "The workflow sandbox issue has been fixed in app/worker.py"
	@echo "The worker now uses SandboxRestriction.UNRESTRICTED"
	@echo "Restart the worker with: make dev"

# =============================================================================
# SIMPLIFIED DEPLOYMENT WORKFLOWS
# =============================================================================

# Quick Docker deployment (recommended for development)
deploy-docker:
	@echo "🚀 Deploying to Docker..."
	@echo "Building images..."
	docker compose build
	@echo "Starting services..."
	docker compose up -d
	@echo "✅ Docker deployment complete!"
	@echo "Services available at:"
	@echo "  - Image Service: http://localhost:8000"
	@echo "  - Temporal UI: http://localhost:8233 (if running locally)"
	@echo ""
	@echo "To generate images: make gen-image"
	@echo "To check status: make status-docker"

# Quick Kubernetes deployment
deploy-k8s:
	@echo "🚀 Deploying to Kubernetes..."
	@echo "Building and loading image to minikube..."
	docker build . -f Dockerfile.worker -t whale-scale:latest
	minikube image load whale-scale:latest
	@echo "Applying Kubernetes manifests..."
	minikube kubectl -- apply -f k8s/namespace.yaml
	minikube kubectl -- apply -f k8s/configmap-env.yaml
	minikube kubectl -- apply -f k8s/services-account.yaml
	minikube kubectl -- apply -f k8s/deployment-worker.yaml
	@echo "✅ Kubernetes deployment complete!"
	@echo ""
	@echo "To submit a job: make submit-k8s"
	@echo "To check logs: make logs-k8s"
	@echo "To check status: make status-k8s"

# Redeploy (rebuild and deploy)
redeploy-docker:
	@echo "🔄 Redeploying to Docker..."
	docker compose down
	docker compose build --no-cache
	docker compose up -d
	@echo "✅ Docker redeployment complete!"

redeploy-k8s:
	@echo "🔄 Redeploying to Kubernetes..."
	docker build . -f Dockerfile.worker -t whale-scale:latest --no-cache
	minikube image load whale-scale:latest
	minikube kubectl -- delete deployment temporal-worker -n temporal || true
	sleep 5
	minikube kubectl -- apply -f k8s/deployment-worker.yaml
	@echo "✅ Kubernetes redeployment complete!"

# =============================================================================
# SIMPLIFIED IMAGE GENERATION
# =============================================================================

# Quick image generation (simple prompt)
gen-image:
	@echo "🎨 Generating image..."
	@read -p "Enter your prompt: " prompt; \
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type text2image --prompt "$$prompt"

# High-quality image generation
gen-image-hq:
	@echo "🎨 Generating high-quality image..."
	@read -p "Enter your prompt: " prompt; \
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type text2image --prompt "$$prompt, highly detailed, 8k resolution" --width 1024 --height 1024 --steps 50 --cfg-scale 15.0

# Quick whale image (for testing)
gen-whale:
	@echo "🐋 Generating whale image..."
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type text2image --prompt "A majestic whale swimming in the deep ocean, highly detailed, 8k resolution" --width 1024 --height 1024 --steps 30

# =============================================================================
# STATUS AND MONITORING
# =============================================================================

# Docker status
status-docker:
	@echo "📊 Docker Status:"
	@echo "==================="
	docker compose ps
	@echo ""
	@echo "🔍 Service Health:"
	@echo "Image Service: $$(curl -s http://localhost:8000/ > /dev/null && echo "✅ Running" || echo "❌ Not running")"

# Kubernetes status
status-k8s:
	@echo "📊 Kubernetes Status:"
	@echo "======================"
	minikube kubectl -- get pods -n temporal
	@echo ""
	minikube kubectl -- get deployments -n temporal

# =============================================================================
# LEGACY COMMANDS (keeping for compatibility)
# =============================================================================

# Docker Compose commands
up:
	docker compose up -d

down:
	docker compose down -v

# Development commands
dev:
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.worker

# Start services
start-temporal:
	@echo "Starting Temporal server..."
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal server start-dev

start-image-service:
	@echo "Starting image generation service..."
	. /tmp/whale-scale-venv/bin/activate && python3 image_generation_service.py

start-all:
	@echo "Starting all services..."
	make start-temporal &
	sleep 3
	make start-image-service &
	sleep 2
	make dev

# Restart services (useful for troubleshooting)
restart-services:
	@echo "Stopping all services..."
	pkill -f "python3.*worker" || true
	pkill -f "python3.*image_generation_service" || true
	pkill -f "temporal server" || true
	sleep 3
	@echo "Starting all services..."
	make start-all

# Cancel all running workflows
cancel-workflows:
	@echo "Canceling all running workflows..."
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal workflow list | grep Running | awk '{print $$2}' | xargs -I{} temporal workflow cancel --workflow-id {}
	@echo "All running workflows canceled"

# Docker build commands
build:
	docker build . -f Dockerfile.worker -t jeric/whale-scale:latest

build-image-service:
	docker build . -f Dockerfile.image-service -t jeric/whale-scale-image-service:latest

# Fixed Kubernetes commands (using minikube kubectl)
kubectl-apply:
	minikube kubectl -- apply -f k8s/namespace.yaml
	minikube kubectl -- apply -f k8s/configmap-env.yaml
	minikube kubectl -- apply -f k8s/services-account.yaml
	minikube kubectl -- apply -f k8s/deployment-worker.yaml

submit-k8s:
	minikube kubectl -- apply -f k8s/job-starter.yaml

logs-k8s:
	minikube kubectl -- logs -f deployment/temporal-worker -n temporal

# Helper commands
start-workflow:
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type hello --name "Jesse"

start-health-check:
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type health_check --containers whale-scale-worker-1

start-text2image:
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type text2image --prompt "A majestic whale swimming in the deep ocean"

# GPU-optimized workflow commands
start-text2image-sdxl:
	@echo "Starting SDXL workflow for maximum GPU utilization (99%+)..."
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type text2image --prompt "A majestic whale swimming in the deep ocean, highly detailed, 8k resolution" --model "stabilityai/stable-diffusion-xl-base-1.0" --width 1024 --height 1024 --steps 50 --cfg-scale 15.0

start-text2image-high-util:
	@echo "Starting high-utilization workflow with SD 1.5..."
	. /tmp/whale-scale-venv/bin/activate && python3 -m app.starter --type text2image --prompt "A majestic whale swimming in the deep ocean, highly detailed, 8k resolution" --model "runwayml/stable-diffusion-v1-5" --width 1024 --height 1024 --steps 50 --cfg-scale 15.0

# GPU monitoring and testing
gpu-monitor:
	@echo "Monitoring GPU usage in real-time..."
	watch -n 1 nvidia-smi

gpu-test:
	@echo "Testing GPU with simple operations..."
	. /tmp/whale-scale-venv/bin/activate && python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU count: {torch.cuda.device_count()}'); print(f'Current device: {torch.cuda.current_device()}'); print(f'Device name: {torch.cuda.get_device_name()}'); a = torch.randn(1000, 1000).cuda(); b = torch.randn(1000, 1000).cuda(); c = torch.mm(a, b); print('GPU test completed successfully!')"

list-models:
	@echo "Listing available models..."
	curl -X GET http://localhost:8000/models/checkpoints

test-sdxl:
	@echo "Testing SDXL generation directly..."
	curl -X POST http://localhost:8000/generate -H "Content-Type: application/json" -d '{"prompt": "A majestic whale swimming in the deep ocean, highly detailed, 8k resolution", "model": "stabilityai/stable-diffusion-xl-base-1.0", "width": 1024, "height": 1024, "steps": 30, "cfg_scale": 15.0, "seed": 42}'

test-multi-gen:
	@echo "Testing multiple simultaneous generations..."
	curl -X POST http://localhost:8000/generate -H "Content-Type: application/json" -d '{"prompt": "A majestic whale swimming in the deep ocean, highly detailed, 8k resolution", "model": "runwayml/stable-diffusion-v1-5", "width": 1024, "height": 1024, "steps": 50, "cfg_scale": 15.0, "seed": 42}' &
	curl -X POST http://localhost:8000/generate -H "Content-Type: application/json" -d '{"prompt": "A beautiful landscape with mountains and lakes, highly detailed, 8k resolution", "model": "runwayml/stable-diffusion-v1-5", "width": 1024, "height": 1024, "steps": 50, "cfg_scale": 15.0, "seed": 43}' &
	curl -X POST http://localhost:8000/generate -H "Content-Type: application/json" -d '{"prompt": "A futuristic city with flying cars and neon lights, highly detailed, 8k resolution", "model": "runwayml/stable-diffusion-v1-5", "width": 1024, "height": 1024, "steps": 50, "cfg_scale": 15.0, "seed": 44}' &

# Temporal monitoring commands
temporal-ui:
	@echo "Opening Temporal Web UI..."
	@echo "URL: http://localhost:8233"
	@echo "If the UI doesn't open automatically, copy and paste the URL into your browser"

temporal-list:
	@echo "Listing all workflows..."
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal workflow list

temporal-describe:
	@echo "Usage: make temporal-describe WORKFLOW_ID=your-workflow-id"
	@echo "Example: make temporal-describe WORKFLOW_ID=text2image-9667"
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal workflow describe --workflow-id $(WORKFLOW_ID)

temporal-task-queue:
	@echo "Viewing task queue statistics..."
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal task-queue describe --task-queue hello-python-tq

temporal-show:
	@echo "Usage: make temporal-show WORKFLOW_ID=your-workflow-id"
	@echo "Example: make temporal-show WORKFLOW_ID=text2image-9667"
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal workflow show --workflow-id $(WORKFLOW_ID)

temporal-query:
	@echo "Usage: make temporal-query WORKFLOW_ID=your-workflow-id"
	@echo "Example: make temporal-query WORKFLOW_ID=text2image-9667"
	export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal workflow query --workflow-id $(WORKFLOW_ID) --query get_status

# Service status and troubleshooting
status:
	@echo "Checking service status..."
	@echo "=== Temporal Server ==="
	curl -s http://localhost:7233/health || echo "Temporal server not responding"
	@echo ""
	@echo "=== Image Generation Service ==="
	curl -s http://localhost:8000/ || echo "Image service not responding"
	@echo ""
	@echo "=== Running Processes ==="
	ps aux | grep -E "(image_generation_service|app.worker|temporal)" | grep -v grep || echo "No services running"
	@echo ""
	@echo "=== GPU Status ==="
	nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits || echo "GPU not available"

check-services:
	@echo "Checking if all services are running..."
	@echo "Temporal server: $$(curl -s http://localhost:7233/health > /dev/null && echo "✅ Running" || echo "❌ Not running")"
	@echo "Image service: $$(curl -s http://localhost:8000/ > /dev/null && echo "✅ Running" || echo "❌ Not running")"
	@echo "Worker: $$(ps aux | grep "app.worker" | grep -v grep > /dev/null && echo "✅ Running" || echo "❌ Not running")"

# Cleanup commands
clean:
	@echo "Cleaning up..."
	rm -rf generated_images/*
	@echo "Generated images cleaned"

clean-all:
	@echo "Cleaning up everything..."
	pkill -f "python3.*worker" || true
	pkill -f "python3.*image_generation_service" || true
	pkill -f "temporal server" || true
	rm -rf generated_images/*
	@echo "All services stopped and images cleaned"

# Test commands
test:
	. /tmp/whale-scale-venv/bin/activate && python3 -m pytest app/tests/ -v

# Setup commands for NVIDIA Docker and Kubernetes (FIXED)
setup-nvidia-docker:
	@echo "Setting up NVIDIA Docker..."
	distribution=$$(. /etc/os-release;echo $$ID$$VERSION_ID) && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - && curl -s -L https://nvidia.github.io/nvidia-docker/$$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
	sudo apt-get update && sudo apt-get install -y nvidia-docker2
	sudo systemctl restart docker

setup-nvidia-k8s:
	@echo "Setting up NVIDIA Kubernetes device plugin..."
	minikube kubectl -- create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml

# =============================================================================
# HELP COMMANDS
# =============================================================================

help:
	@echo "🐋 Whale Scale - Available Commands"
	@echo "===================================="
	@echo ""
	@echo "🚀 QUICK DEPLOYMENT:"
	@echo "  deploy-docker     - Deploy to Docker (recommended for dev)"
	@echo "  deploy-k8s        - Deploy to Kubernetes"
	@echo "  redeploy-docker   - Rebuild and redeploy to Docker"
	@echo "  redeploy-k8s      - Rebuild and redeploy to Kubernetes"
	@echo ""
	@echo "🎨 IMAGE GENERATION:"
	@echo "  gen-image         - Generate image with custom prompt"
	@echo "  gen-image-hq      - Generate high-quality image"
	@echo "  gen-whale         - Generate a whale image (for testing)"
	@echo ""
	@echo "📊 STATUS & MONITORING:"
	@echo "  status-docker     - Check Docker deployment status"
	@echo "  status-k8s        - Check Kubernetes deployment status"
	@echo "  gpu-monitor       - Monitor GPU usage"
	@echo ""
	@echo "🔧 LEGACY COMMANDS:"
	@echo "  up/down           - Docker compose up/down"
	@echo "  build             - Build Docker images"
	@echo "  dev               - Run worker locally"
	@echo ""
	@echo "For more commands, see the Makefile"

.PHONY: install fix-dependencies fix-sandbox up down dev build build-image-service kubectl-apply submit-k8s logs-k8s test clean clean-all setup-nvidia-docker setup-nvidia-k8s start-workflow start-health-check start-text2image start-text2image-sdxl start-text2image-high-util gpu-monitor gpu-test list-models test-sdxl test-multi-gen start-temporal start-image-service start-all restart-services status check-services temporal-ui temporal-list temporal-describe temporal-task-queue temporal-show temporal-query cancel-workflows deploy-docker deploy-k8s redeploy-docker redeploy-k8s gen-image gen-image-hq gen-whale status-docker status-k8s help
.DEFAULT_GOAL := help
