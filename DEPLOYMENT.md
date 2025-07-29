# 🚀 Fast Deployment Guide

This guide explains how to quickly redeploy your Whale Scale application without redownloading dependencies every time.

## 🎯 Quick Start

For the fastest development experience, use the quick deploy script:

```bash
./quick-deploy.sh          # Fast redeploy (preserves dependencies)
./quick-deploy.sh local    # Deploy with local Temporal server
./quick-deploy.sh status   # Check deployment status
```

## ⚡ Fast Deployment Commands

### Docker (Recommended for Development)

```bash
# Fastest option - preserves dependency layers
make fast-redeploy-docker

# Deploy with local Temporal server (fixes connection issues)
make deploy-docker-local

# Initial deployment with caching
make deploy-docker
```

### Kubernetes

```bash
# Fast Kubernetes redeploy
make fast-redeploy-k8s

# Initial Kubernetes deployment
make deploy-k8s
```

## 🧹 Cache Management

When dependencies change significantly:

```bash
# Clean build cache and redeploy
make clean-cache && make deploy-docker

# Nuclear option - clean everything
make clean-all-docker

# Check Docker disk usage
make docker-usage
```

## 🔧 How It Works

### Multi-Stage Docker Builds

The optimized Dockerfiles use multi-stage builds:

1. **Base stage**: System dependencies (rarely changes)
2. **Dependencies stage**: Python packages (changes when requirements.txt changes)
3. **Final stage**: Application code (changes frequently)

This means when you modify your app code, Docker only rebuilds the final stage, preserving the expensive dependency installation layers.

### Docker BuildKit

All fast commands use `DOCKER_BUILDKIT=1` for:
- Parallel layer builds
- Better caching
- Faster dependency resolution

### Docker Compose Override

The `docker-compose.override.yml` file automatically:
- Fixes Temporal networking (`host.docker.internal:7233`)
- Enables hot reload for development
- Provides local Temporal server option

## 🚨 Troubleshooting

### Temporal Connection Issues

**Problem**: `Connection refused` to `172.21.181.91:7233`

**Solutions**:
1. Use local Temporal: `./quick-deploy.sh local`
2. Check if external Temporal server is running
3. Verify network connectivity to the Temporal server

### Slow Builds

**Problem**: Docker still rebuilding dependencies

**Solutions**:
1. Ensure you're using fast commands: `make fast-redeploy-docker`
2. Check if `requirements.txt` changed (forces dependency rebuild)
3. Clean cache if needed: `make clean-cache`

### Out of Disk Space

**Problem**: Docker consuming too much space

**Solutions**:
1. Check usage: `make docker-usage`
2. Clean build cache: `make clean-cache`
3. Nuclear clean: `make clean-all-docker`

## 📊 Performance Comparison

| Command | First Build | Code Change | Dependency Change |
|---------|-------------|-------------|-------------------|
| `redeploy-docker` (old) | 5-10 min | 5-10 min | 5-10 min |
| `fast-redeploy-docker` | 5-10 min | 30-60 sec | 2-3 min |
| `deploy-docker-local` | 6-12 min | 30-60 sec | 2-3 min |

## 🔄 Development Workflow

### Typical Development Session

1. **Initial setup** (once):
   ```bash
   ./quick-deploy.sh local
   ```

2. **Code changes** (frequent):
   ```bash
   ./quick-deploy.sh
   ```

3. **Dependency changes** (occasional):
   ```bash
   make clean-cache && make deploy-docker
   ```

### Testing Different Environments

```bash
# Local development with hot reload
./quick-deploy.sh local

# Production-like Docker environment
./quick-deploy.sh

# Kubernetes testing
./quick-deploy.sh k8s
```

## 🌐 Service URLs

### Docker Deployment
- Image Service: http://localhost:8000
- External Temporal: 172.21.181.91:7233

### Local Temporal Deployment
- Image Service: http://localhost:8000
- Temporal UI: http://localhost:8233
- Temporal Server: localhost:7233

### Kubernetes Deployment
- Services run in Minikube cluster
- Check status: `make status-k8s`
- View logs: `make logs-k8s`

## 💡 Pro Tips

1. **Use the quick script**: `./quick-deploy.sh` is the fastest way to redeploy
2. **Local Temporal for development**: Avoids external server dependencies
3. **Monitor Docker usage**: Run `make docker-usage` periodically
4. **Hot reload**: The override file enables hot reload for faster iteration
5. **BuildKit**: Always enabled in fast commands for better performance

## 🔍 Debugging

### Check Service Status
```bash
./quick-deploy.sh status
make status-docker
```

### View Logs
```bash
docker compose logs -f worker
docker compose logs -f image-service
```

### Test Connectivity
```bash
curl http://localhost:8000/     # Image service
curl http://localhost:8233/     # Temporal UI (if local)
```

This deployment system is designed to give you the fastest possible development experience while maintaining production-ready containerization. 