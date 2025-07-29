# =============================================================================
# WHALE SCALE - Smart Multi-Environment Makefile
# =============================================================================

# Load environment configuration
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values if .env doesn't exist
ENVIRONMENT ?= docker
TEMPORAL_SERVER_PORT ?= 7233
IMAGE_SERVICE_PORT ?= 8000
TEMPORAL_API_PORT ?= 8002
ADMIN_PORT ?= 8080
TEMPORAL_UI_PORT ?= 8233
DOCKER_COMPOSE_PROFILE ?= local-temporal
VENV_PATH ?= /tmp/whale-scale-venv

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

.PHONY: help startall stopall status env-info clean setup test

# =============================================================================
# MAIN COMMANDS
# =============================================================================

help: ## Show this help message
	@echo "$(BLUE)🐋 Whale Scale - AI Image Generation Platform$(NC)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  make startall    - Start all services (auto-detects environment)"
	@echo "  make stopall     - Stop all services"
	@echo "  make status      - Check service status"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

startall: env-info ## Start all services based on environment
	@echo "$(GREEN)🚀 Starting Whale Scale ($(ENVIRONMENT) environment)...$(NC)"
ifeq ($(ENVIRONMENT),docker)
	@$(MAKE) start-docker
else ifeq ($(ENVIRONMENT),local)
	@$(MAKE) start-local
else ifeq ($(ENVIRONMENT),k8s)
	@$(MAKE) start-k8s
else
	@echo "$(RED)❌ Unknown environment: $(ENVIRONMENT)$(NC)"
	@echo "Set ENVIRONMENT in .env to: docker, local, or k8s"
	@exit 1
endif
	@echo ""
	@echo "$(GREEN)✅ Services started!$(NC)"
	@$(MAKE) show-urls

stopall: ## Stop all services
	@echo "$(YELLOW)🛑 Stopping all services...$(NC)"
	@$(MAKE) stop-docker 2>/dev/null || true
	@$(MAKE) stop-local 2>/dev/null || true
	@$(MAKE) stop-k8s 2>/dev/null || true
	@echo "$(GREEN)✅ All services stopped$(NC)"

status: ## Check status of all services
	@echo "$(BLUE)📊 Service Status$(NC)"
	@echo "Environment: $(ENVIRONMENT)"
	@echo ""
	@$(MAKE) check-services

env-info: ## Show environment information
	@echo "$(BLUE)🔧 Environment Configuration$(NC)"
	@echo "Environment: $(ENVIRONMENT)"
	@echo "Temporal Server: localhost:$(TEMPORAL_SERVER_PORT)"
	@echo "Image Service: localhost:$(IMAGE_SERVICE_PORT)"
	@echo "Temporal API: localhost:$(TEMPORAL_API_PORT)"
	@echo "Admin Interface: localhost:$(ADMIN_PORT)"
	@echo "Temporal UI: localhost:$(TEMPORAL_UI_PORT)"
	@echo ""

# =============================================================================
# DOCKER ENVIRONMENT
# =============================================================================

start-docker: ## Start Docker environment
	@echo "$(GREEN)🐳 Starting Docker services...$(NC)"
	@docker compose --profile $(DOCKER_COMPOSE_PROFILE) down 2>/dev/null || true
	@docker compose --profile $(DOCKER_COMPOSE_PROFILE) up -d
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo "$(GREEN)✅ Docker services started!$(NC)"
	@echo "$(GREEN)🔗 Starting Temporal API server...$(NC)"
	@./start-temporal-api.sh $(TEMPORAL_API_PORT) $(TEMPORAL_SERVER_PORT) $(IMAGE_SERVICE_PORT) $(VENV_PATH) || true
	@echo "$(GREEN)✅ All services ready!$(NC)"

stop-docker: ## Stop Docker services
	@echo "$(YELLOW)🐳 Stopping Docker services...$(NC)"
	@docker compose --profile $(DOCKER_COMPOSE_PROFILE) down
	@$(MAKE) stop-temporal-api

start-temporal-api-docker: ## Start Temporal API server for Docker environment
	@echo "$(GREEN)Starting Temporal API server for Docker...$(NC)"
	@pkill -f "temporal_api_server.py" 2>/dev/null || true
	@sleep 2
	@(. $(VENV_PATH)/bin/activate 2>/dev/null || python3 -m venv $(VENV_PATH) && . $(VENV_PATH)/bin/activate && pip install -r requirements.txt >/dev/null 2>&1) && \
	 . $(VENV_PATH)/bin/activate && \
	 TEMPORAL_TARGET=localhost:$(TEMPORAL_SERVER_PORT) \
	 IMAGE_SERVICE_URL=http://localhost:$(IMAGE_SERVICE_PORT) \
	 python3 temporal_api_server.py &
	@sleep 3

# =============================================================================
# LOCAL ENVIRONMENT
# =============================================================================

start-local: ## Start local development environment
	@echo "$(GREEN)💻 Starting local services...$(NC)"
	@$(MAKE) setup-venv
	@$(MAKE) stop-local 2>/dev/null || true
	@$(MAKE) start-temporal-local &
	@sleep 5
	@$(MAKE) start-image-service-local &
	@sleep 3
	@$(MAKE) start-temporal-api-local &
	@sleep 3
	@$(MAKE) start-worker-local &
	@sleep 2

stop-local: ## Stop local services
	@echo "$(YELLOW)💻 Stopping local services...$(NC)"
	@pkill -f "temporal server" 2>/dev/null || true
	@pkill -f "image_generation_service.py" 2>/dev/null || true
	@pkill -f "temporal_api_server.py" 2>/dev/null || true
	@pkill -f "app.worker" 2>/dev/null || true
	@pkill -f "http.server" 2>/dev/null || true

start-temporal-local:
	@echo "Starting Temporal server..."
	@export PATH="$$PATH:/home/jeric/.temporalio/bin" && temporal server start-dev &

start-image-service-local:
	@echo "Starting image generation service..."
	@. $(VENV_PATH)/bin/activate && \
	 HOST=localhost PORT=$(IMAGE_SERVICE_PORT) python3 image_generation_service.py &

start-temporal-api-local:
	@echo "Starting Temporal API server..."
	@. $(VENV_PATH)/bin/activate && \
	 TEMPORAL_TARGET=localhost:$(TEMPORAL_SERVER_PORT) \
	 python3 temporal_api_server.py &

start-worker-local:
	@echo "Starting Temporal worker..."
	@. $(VENV_PATH)/bin/activate && \
	 TEMPORAL_TARGET=localhost:$(TEMPORAL_SERVER_PORT) \
	 TASK_QUEUE=$(TEMPORAL_TASK_QUEUE) \
	 IMAGE_GENERATION_SERVICE_URL=http://localhost:$(IMAGE_SERVICE_PORT) \
	 python3 -m app.worker &

# =============================================================================
# KUBERNETES ENVIRONMENT
# =============================================================================

start-k8s: ## Start Kubernetes environment
	@echo "$(GREEN)☸️ Starting Kubernetes services...$(NC)"
	@echo "$(RED)❌ Kubernetes support coming soon!$(NC)"
	@exit 1

stop-k8s: ## Stop Kubernetes services
	@echo "$(YELLOW)☸️ Stopping Kubernetes services...$(NC)"
	@echo "$(RED)❌ Kubernetes support coming soon!$(NC)"

# =============================================================================
# ADMIN INTERFACE
# =============================================================================

start-admin: ## Start admin web interface
	@./start-admin.sh $(ADMIN_PORT)

stop-admin: ## Stop admin interface
	@./stop-admin.sh $(ADMIN_PORT)

# =============================================================================
# UTILITIES
# =============================================================================

setup-venv: ## Set up Python virtual environment
	@if [ ! -d "$(VENV_PATH)" ]; then \
		echo "$(GREEN)🐍 Creating Python virtual environment...$(NC)"; \
		python3 -m venv $(VENV_PATH); \
		. $(VENV_PATH)/bin/activate && pip install --upgrade pip; \
		. $(VENV_PATH)/bin/activate && pip install -r requirements.txt; \
	fi

stop-temporal-api: ## Stop Temporal API server
	@pkill -f "temporal_api_server.py" 2>/dev/null || true

check-services: ## Check if services are running
	@echo "$(BLUE)🔍 Checking services...$(NC)"
	@echo ""
	@echo "$(YELLOW)Image Service (Primary):$(NC)"
	@curl -s http://localhost:$(IMAGE_SERVICE_PORT)/ 2>/dev/null >/dev/null && echo " ✅ Running" || echo " ❌ Not responding"
	@echo ""
	@echo "$(YELLOW)Admin Interface:$(NC)"
	@curl -s http://localhost:$(ADMIN_PORT)/ 2>/dev/null >/dev/null && echo " ✅ Running" || echo " ❌ Not responding"
	@echo ""
	@echo "$(YELLOW)Docker Containers:$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep whale-scale || echo " ❌ No containers running"
	@echo ""
	@echo "$(YELLOW)Optional Services:$(NC)"
	@echo -n "  Temporal Server: " && (curl -s http://localhost:$(TEMPORAL_SERVER_PORT)/health 2>/dev/null >/dev/null && echo "✅" || echo "❌ (not needed for basic usage)")
	@echo -n "  Temporal API: " && (curl -s http://localhost:$(TEMPORAL_API_PORT)/health 2>/dev/null >/dev/null && echo "✅" || echo "❌ (not needed for basic usage)")

show-urls: ## Show service URLs
	@echo ""
	@echo "$(GREEN)🌐 Service URLs:$(NC)"
	@echo "  Admin Interface: http://localhost:$(ADMIN_PORT)/admin.html"
	@echo "  Temporal UI: http://localhost:$(TEMPORAL_UI_PORT)"
	@echo "  Image Service: http://localhost:$(IMAGE_SERVICE_PORT)"
	@echo "  Temporal API: http://localhost:$(TEMPORAL_API_PORT)"
	@echo ""
	@echo "$(BLUE)💡 Tip: Run 'make status' to check if services are healthy$(NC)"

clean: ## Clean up generated files and containers
	@echo "$(YELLOW)🧹 Cleaning up...$(NC)"
	@$(MAKE) stopall
	@docker system prune -f 2>/dev/null || true
	@rm -rf $(OUTPUT_DIR)/*.png 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

test: ## Run tests
	@echo "$(BLUE)🧪 Running tests...$(NC)"
	@. $(VENV_PATH)/bin/activate && python3 -m pytest app/tests/ -v

# =============================================================================
# DEVELOPMENT SHORTCUTS
# =============================================================================

dev: ## Start everything for development (Docker + Admin)
	@echo "$(GREEN)🚀 Starting development environment...$(NC)"
	@$(MAKE) startall
	@sleep 3
	@./start-admin.sh $(ADMIN_PORT)
	@echo "$(GREEN)✅ Development environment ready!$(NC)"
	@echo ""
	@echo "$(GREEN)🌐 Service URLs:$(NC)"
	@echo "  Admin Interface: http://localhost:$(ADMIN_PORT)/admin.html"
	@echo "  Image Service: http://localhost:$(IMAGE_SERVICE_PORT)"
	@echo "  Temporal UI: http://localhost:$(TEMPORAL_UI_PORT)"
	@echo ""
	@echo "$(BLUE)💡 Generate images at: http://localhost:$(ADMIN_PORT)/admin.html$(NC)"

logs-docker: ## Show Docker container logs
	@docker compose logs -f

restart: stopall startall ## Restart all services

quick-test: ## Quick test of image generation
	@echo "$(BLUE)🧪 Testing image generation...$(NC)"
	@echo "Testing direct image service..."
	@curl -X POST http://localhost:$(IMAGE_SERVICE_PORT)/generate \
		-H "Content-Type: application/json" \
		-d '{"prompt": "test image", "model": "runwayml/stable-diffusion-v1-5"}' \
		2>/dev/null && echo "" && echo "$(GREEN)✅ Image generation test successful!$(NC)" || echo "$(RED)❌ Image generation test failed$(NC)"
