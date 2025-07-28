#!/bin/bash

# Test script for ComfyUI models with Whale Scale Temporal App

echo "🎨 Testing ComfyUI Models with Whale Scale"
echo "=========================================="

# Check if services are running
echo "🔍 Checking if services are running..."

if ! curl -s http://localhost:8000/ > /dev/null 2>&1; then
    echo "❌ Image generation service not running. Start with: make up"
    exit 1
fi

if ! curl -s http://localhost:7233/health > /dev/null 2>&1; then
    echo "❌ Temporal server not running. Start with: temporal server start-dev"
    exit 1
fi

echo "✅ Services are running"

# List available models
echo ""
echo "📋 Available models:"
curl -s http://localhost:8000/models | python3 -m json.tool

# Test different model types
echo ""
echo "🧪 Testing different model types..."

# Test 1: SD1.5 model
echo ""
echo "1️⃣ Testing SD1.5 model..."
python3 -m app.starter --type text2image \
  --prompt "A beautiful whale swimming in crystal clear water, high quality, detailed" \
  --negative-prompt "blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, nsfw, grainy, noisy, overexposed, underexposed
" \
  --model "SD1.5/stable-diffusion-v1-5.safetensors" \
  --width 512 --height 512 \
  --steps 20 --cfg-scale 7.5 \
  --seed 42

# Test 2: FLUX1 model (if available)
echo ""
echo "2️⃣ Testing FLUX1 model..."
python3 -m app.starter --type text2image \
  --prompt "A majestic whale swimming in the deep ocean, cinematic lighting, high quality" \
  --negative-prompt blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, nsfw, grainy, noisy, overexposed, underexposed
" \
  --model "FLUX1/flux1-schnell-fp8.safetensors" \
  --width 512 --height 512 \
  --steps 20 --cfg-scale 7.5 \
  --seed 123

# Test 3: SDXL model (if available)
echo ""
echo "3️⃣ Testing SDXL model..."
python3 -m app.starter --type text2image \
  --prompt "A stunning whale breaching the ocean surface, golden hour lighting, ultra detailed" \
  --negative-prompt blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, nsfw, grainy, noisy, overexposed, underexposed
, ugly" \
  --model "SDXL/sdxl-base-1.0.safetensors" \
  --width 768 --height 768 \
  --steps 25 --cfg-scale 8.0 \
  --seed 456

echo ""
echo "✅ Testing complete! Check ./generated_images/ for results"
echo ""
echo "📊 Generated images:"
ls -la generated_images/ 2>/dev/null || echo "No images generated yet" 