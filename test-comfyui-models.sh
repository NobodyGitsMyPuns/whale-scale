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

# Get available models dynamically
echo ""
echo "📋 Fetching available models..."
MODELS_JSON=$(curl -s http://localhost:8000/models/text2image)
if [ $? -ne 0 ]; then
    echo "❌ Failed to fetch models from service"
    exit 1
fi

# Extract model names
MODEL1=$(echo "$MODELS_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); models = [m['name'] for m in data['models'] if m['type'] == 'checkpoint']; print(models[0] if models else 'runwayml/stable-diffusion-v1-5')")
MODEL2=$(echo "$MODELS_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); models = [m['name'] for m in data['models'] if m['type'] == 'checkpoint']; print(models[1] if len(models) > 1 else models[0] if models else 'runwayml/stable-diffusion-v1-5')")
MODEL3=$(echo "$MODELS_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); models = [m['name'] for m in data['models'] if m['type'] == 'checkpoint']; print(models[2] if len(models) > 2 else models[0] if models else 'runwayml/stable-diffusion-v1-5')")

echo "🎯 Selected models for testing:"
echo "   Model 1: $MODEL1"
echo "   Model 2: $MODEL2" 
echo "   Model 3: $MODEL3"

# Test different model types
echo ""
echo "🧪 Testing different model types..."

# Test 1: First available model
echo ""
echo "1️⃣ Testing model: $MODEL1"
python3 -m app.starter --type text2image \
  --prompt "A beautiful whale swimming in crystal clear water, high quality, detailed" \
  --negative-prompt "blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, grainy, noisy, overexposed, underexposed" \
  --model "$MODEL1" \
  --width 512 --height 512 \
  --steps 20 --cfg-scale 7.5 \
  --seed 42

# Test 2: Second available model
echo ""
echo "2️⃣ Testing model: $MODEL2"
python3 -m app.starter --type text2image \
  --prompt "A majestic whale swimming in the deep ocean, cinematic lighting, high quality" \
  --negative-prompt "blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, grainy, noisy, overexposed, underexposed" \
  --model "$MODEL2" \
  --width 512 --height 512 \
  --steps 20 --cfg-scale 7.5 \
  --seed 123

# Test 3: Third available model
echo ""
echo "3️⃣ Testing model: $MODEL3"
python3 -m app.starter --type text2image \
  --prompt "A stunning whale breaching the ocean surface, golden hour lighting, ultra detailed" \
  --negative-prompt "blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, grainy, noisy, overexposed, underexposed, ugly" \
  --model "$MODEL3" \
  --width 768 --height 768 \
  --steps 25 --cfg-scale 8.0 \
  --seed 456

echo ""
echo "✅ Testing complete! Check ./generated_images/ for results"
echo ""
echo "📊 Generated images:"
ls -la generated_images/ 2>/dev/null || echo "No images generated yet" 