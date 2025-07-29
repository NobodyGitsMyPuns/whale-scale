# 🐋 Whale Scale - AI Image Generation Platform

A scalable AI image generation platform using Temporal workflows, Docker, and Stable Diffusion.

## 🚀 Quick Start

### 1. Choose Your Environment

Edit `.env` to set your preferred environment:

```bash
# Options: docker, local, k8s
ENVIRONMENT=docker
```

### 2. Start Everything

```bash
make startall
```

That's it! The system will:
- Auto-detect your environment
- Start all required services 
- Show you the service URLs
- Launch with proper queue management

### 3. Generate Images

Open the admin interface: http://localhost:8080/admin.html

The interface automatically detects whether you're using:
- **Temporal workflows** (queued, scalable) 
- **Direct image service** (immediate, simple)

## 📋 Available Commands

```bash
make help          # Show all commands
make startall      # Start all services
make stopall       # Stop all services  
make status        # Check service health
make dev           # Start everything + admin interface
make restart       # Restart all services
make clean         # Clean up everything
```

## 🔧 Environments

### Docker (Recommended)
```bash
# .env
ENVIRONMENT=docker
```
- Uses Docker containers for all services
- Includes Temporal server, worker, and image service
- GPU support via nvidia-docker
- Most reliable and isolated

### Local Development
```bash
# .env  
ENVIRONMENT=local
```
- Runs services directly on your machine
- Requires Python virtual environment
- Good for development and debugging
- Direct access to logs and processes

### Kubernetes (Coming Soon)
```bash
# .env
ENVIRONMENT=k8s  
```
- Production-ready Kubernetes deployment
- Auto-scaling and high availability
- Currently in development

## 🌐 Service URLs

After running `make startall`, you'll have:

- **Admin Interface**: http://localhost:8080/admin.html
- **Temporal UI**: http://localhost:8233  
- **Image Service**: http://localhost:8000
- **Temporal API**: http://localhost:8002

## 🧠 How It Works

### Architecture

```
Admin Interface → Temporal API → Temporal Server → Worker → Image Service
                                     ↓
                              Queue Management
```

### Smart Environment Detection

The admin interface automatically detects your environment:

- **Temporal Mode**: Uses workflow queues (scalable, fault-tolerant)
- **Direct Mode**: Calls image service directly (simple, immediate)

### Queue vs Direct Generation

**Temporal Workflows (Recommended)**:
- ✅ Queued execution
- ✅ Fault tolerance  
- ✅ Scalability
- ✅ Progress tracking
- ✅ Retry logic

**Direct Generation**:
- ✅ Immediate execution
- ✅ Simple setup
- ❌ No queuing
- ❌ No fault tolerance

## 🛠️ Configuration

### Environment Variables (.env)

```bash
# Environment type
ENVIRONMENT=docker

# Service ports  
TEMPORAL_SERVER_PORT=7233
IMAGE_SERVICE_PORT=8000
TEMPORAL_API_PORT=8002
ADMIN_PORT=8080

# Paths
COMFYUI_MODELS_DIR=/path/to/your/models
OUTPUT_DIR=./generated_images

# GPU
CUDA_VISIBLE_DEVICES=0
```

### Docker Configuration

The system uses `docker-compose.yml` with smart profiles:

```bash
# Start with local Temporal server
docker compose --profile local-temporal up -d

# Start basic services only  
docker compose up -d
```

## 🐛 Troubleshooting

### Check Service Status
```bash
make status
```

### View Logs
```bash
# Docker logs
make logs-docker

# Check specific service
docker logs whale-scale-worker-1
```

### Common Issues

**"Services not starting"**:
```bash
make clean
make startall
```

**"GPU not detected"**:
- Ensure nvidia-docker is installed
- Check `nvidia-smi` works
- Verify `CUDA_VISIBLE_DEVICES` in `.env`

**"Temporal connection failed"**:
- Check if port 7233 is available
- Try restarting: `make restart`

**"Admin interface shows wrong environment"**:
- The interface auto-detects based on service availability
- Ensure your preferred services are running

## 🧪 Testing

### Quick Test
```bash
make quick-test
```

### Full Test Suite
```bash
make test
```

### Manual Testing
```bash
# Test Temporal workflow
curl -X POST http://localhost:8002/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test image"}'

# Test direct image service  
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test image"}'
```

## 📦 Requirements

### System Requirements
- Docker & Docker Compose
- NVIDIA GPU (optional but recommended)
- Python 3.10+
- 8GB+ RAM
- 10GB+ disk space

### GPU Requirements (Optional)
- NVIDIA GPU with CUDA support
- nvidia-docker installed
- 4GB+ VRAM for basic models
- 8GB+ VRAM for SDXL models

## 🔄 Development Workflow

### 1. Make Changes
Edit your code in `app/`, `image_generation_service.py`, etc.

### 2. Restart Services  
```bash
make restart
```

### 3. Test Changes
```bash
make quick-test
```

### 4. View Logs
```bash
make logs-docker
```

## 🏗️ Architecture Details

### Components

1. **Temporal Server**: Workflow orchestration
2. **Temporal Worker**: Executes workflow tasks  
3. **Image Service**: Stable Diffusion inference
4. **Temporal API**: HTTP bridge to workflows
5. **Admin Interface**: Web UI for image generation

### Data Flow

1. User submits prompt via admin interface
2. Admin interface detects environment and calls appropriate API
3. **Temporal Mode**: API creates workflow → queued → worker executes
4. **Direct Mode**: API calls image service immediately  
5. Image service generates image using Stable Diffusion
6. Result returned to user interface

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `make test`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

---

## 💡 Tips

- Use `make dev` for the full development setup
- Monitor GPU usage with `nvidia-smi`  
- Check Temporal UI at http://localhost:8233 for workflow insights
- Use Docker environment for most reliable experience
- Set `ENVIRONMENT=local` only for debugging specific issues


