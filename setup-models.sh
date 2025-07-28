#!/bin/bash

# Setup script for Whale Scale Temporal App with GPU Image Generation

set -e

echo "🐋 Setting up Whale Scale Temporal App with GPU Image Generation"
echo "================================================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if NVIDIA Docker is available
if ! docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi > /dev/null 2>&1; then
    echo "⚠️  NVIDIA Docker not available. GPU acceleration will not work."
    echo "   Install NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
fi

# Check for ComfyUI models directory
COMFYUI_MODELS_DIR="C:/Users/jeric/Documents/ComfyUI/models"
echo "🔍 Checking for ComfyUI models directory..."

if [ ! -d "$COMFYUI_MODELS_DIR" ]; then
    echo "❌ ComfyUI models directory not found: $COMFYUI_MODELS_DIR"
    echo "   Please ensure ComfyUI is installed and models are downloaded."
    echo "   Expected path: $COMFYUI_MODELS_DIR"
    echo ""
    echo "   If your ComfyUI is installed elsewhere, update the path in:"
    echo "   - docker-compose.yml"
    echo "   - image_generation_service.py"
    echo ""
    read -p "Press Enter to continue anyway (you can update paths later)..."
else
    echo "✅ Found ComfyUI models directory: $COMFYUI_MODELS_DIR"
    
    # Check for checkpoints
    if [ -d "$COMFYUI_MODELS_DIR/checkpoints" ]; then
        echo "📁 Found checkpoints directory with subdirectories:"
        ls -la "$COMFYUI_MODELS_DIR/checkpoints/"
    else
        echo "⚠️  No checkpoints directory found"
    fi
    
    # Check for other model types
    for model_type in "loras" "controlnet" "vae" "embeddings" "upscale_models"; do
        if [ -d "$COMFYUI_MODELS_DIR/$model_type" ]; then
            count=$(find "$COMFYUI_MODELS_DIR/$model_type" -name "*.safetensors" -o -name "*.ckpt" -o -name "*.bin" | wc -l)
            echo "📁 Found $model_type directory with $count models"
        fi
    done
fi

# Create output directory
echo "📁 Creating output directory..."
mkdir -p generated_images

# Set up environment variables
echo "🔧 Setting up environment..."
export COMFYUI_MODELS_DIR="$COMFYUI_MODELS_DIR"
export OUTPUT_DIR="$(pwd)/generated_images"

echo "📋 Environment configuration:"
echo "   COMFYUI_MODELS_DIR: $COMFYUI_MODELS_DIR"
echo "   OUTPUT_DIR: $OUTPUT_DIR"

# Build Docker images
echo "🔨 Building Docker images..."
make build
make build-image-service

# Start services
echo "🚀 Starting services..."
make up

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Service Status:"
echo "   - Temporal Server: http://localhost:8233"
echo "   - Image Generation Service: http://localhost:8000"
echo "   - Generated Images: ./generated_images/"
echo "   - ComfyUI Models: $COMFYUI_MODELS_DIR"
echo ""
echo "🎯 Next steps:"
echo "   1. Start Temporal server: export PATH=\"\$PATH:/home/jeric/.temporalio/bin\" && temporal server start-dev"
echo "   2. Run worker: make dev"
echo "   3. Generate images: make start-text2image"
echo ""
echo "🔧 Useful commands:"
echo "   - View logs: docker compose logs -f"
echo "   - Stop services: make down"
echo "   - Check image service: curl http://localhost:8000/"
echo "   - List models: curl http://localhost:8000/models"
echo "   - List checkpoints: curl http://localhost:8000/models/checkpoints"
echo ""
echo "📝 Model Usage Examples:"
echo "   - Use a checkpoint: python3 -m app.starter --type text2image --model \"SD1.5/stable-diffusion-v1-5.safetensors\""
echo "   - Use FLUX1 model: python3 -m app.starter --type text2image --model \"FLUX1/flux1-schnell-fp8.safetensors\""
echo "   - Use SDXL model: python3 -m app.starter --type text2image --model \"SDXL/sdxl-base-1.0.safetensors\"" 