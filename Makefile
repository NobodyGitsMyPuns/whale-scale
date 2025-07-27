# Installation and setup
install:
	@echo "Installing dependencies..."
	@echo "Installing Python virtual environment tools..."
	sudo apt update && sudo apt install -y python3-venv python3-pip || echo "Skipping apt install (not Ubuntu/Debian)"
	@echo "Creating virtual environment..."
	python3 -m venv .venv
	@echo "Activating virtual environment and installing Python dependencies..."
	. .venv/bin/activate && pip install -r requirements.txt
	@echo "Installing Temporal CLI..."
	curl -sSf https://temporal.download/cli.sh | sh
	@echo "Installation complete!"
	@echo "To activate the virtual environment, run: source .venv/bin/activate"
	@echo "To add Temporal CLI to PATH, run: export PATH=\"\$$PATH:/home/jeric/.temporalio/bin\""

# Docker Compose commands
up:
	docker compose up -d

down:
	docker compose down -v

# Development commands
dev:
	. .venv/bin/activate && python3 -m app.worker

# Docker build commands
build:
	docker build . -f Dockerfile.worker -t jeric/whale-scale:latest

# Kubernetes commands
kubectl-apply:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmap-env.yaml
	kubectl apply -f k8s/services-account.yaml
	kubectl apply -f k8s/deployment-worker.yaml

submit:
	kubectl apply -f k8s/job-starter.yaml

logs:
	kubectl logs -f deployment/temporal-worker -n temporal

# Helper commands
start-workflow:
	. .venv/bin/activate && python3 -m app.starter --name "Jesse"

# Testing commands
test:
	. .venv/bin/activate && python3 -m pytest

# Clean up commands
clean:
	docker compose down -v
	docker system prune -f

# NVIDIA GPU setup for Docker
setup-nvidia-docker:
	@echo "Setting up NVIDIA Container Toolkit..."
	@echo "1. Install NVIDIA drivers: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/"
	@echo "2. Install NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
	@echo "3. Restart Docker: sudo systemctl restart docker"

# NVIDIA GPU setup for Kubernetes
setup-nvidia-k8s:
	@echo "Installing NVIDIA Device Plugin..."
	kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/nvidia-device-plugin.yml
	@echo "NVIDIA Device Plugin installed. Check with: kubectl get pods -n kube-system | grep nvidia-device-plugin"

# Default target
.PHONY: install up down dev build kubectl-apply submit logs test clean setup-nvidia-docker setup-nvidia-k8s start-workflow
.DEFAULT_GOAL := up
