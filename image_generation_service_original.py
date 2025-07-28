#!/usr/bin/env python3
"""
Image Generation Microservice
Runs Stable Diffusion models locally on GPU using ComfyUI model structure
"""

import asyncio
import base64
import json
import os
import time
import uuid
from pathlib import Path
from typing import Dict, Optional, List
import logging

import torch
from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
from diffusers.pipelines.stable_diffusion.convert_from_ckpt import download_from_original_stable_diffusion_ckpt
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import os
import json
import uuid
import logging
import asyncio
from typing import Dict, Optional
import aiofiles
from datetime import datetime
import torch.serialization

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global variables
app = FastAPI(title="Image Generation Service", version="1.0.0")
pipeline = None
models_cache = {}
tasks = {}

# ComfyUI models directory - adjust this to your ComfyUI models path
COMFYUI_MODELS_DIR = os.getenv("COMFYUI_MODELS_DIR", "/mnt/c/Users/jeric/Documents/ComfyUI/models")
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "./generated_images")

# Ensure output directory exists
os.makedirs(OUTPUT_DIR, exist_ok=True)

class GenerationRequest(BaseModel):
    prompt: str
    negative_prompt: str = ""
    model: str = "stable-diffusion-v1-5"
    width: int = 512
    height: int = 512
    steps: int = 20
    cfg_scale: float = 7.5
    seed: int = -1
    sampler: str = "euler"
    scheduler: str = "normal"

class GenerationTask:
    def __init__(self, task_id: str, request: GenerationRequest):
        self.task_id = task_id
        self.request = request
        self.status = "pending"
        self.progress = 0
        self.result = None
        self.error = None
        self.start_time = None
        self.end_time = None

def get_available_models() -> Dict[str, List[str]]:
    """Get list of available models from the ComfyUI models directory."""
    models = {
        "checkpoints": [],
        "loras": [],
        "controlnet": [],
        "vae": [],
        "embeddings": [],
        "upscale_models": []
    }
    
    if not os.path.exists(COMFYUI_MODELS_DIR):
        logger.warning(f"ComfyUI models directory not found: {COMFYUI_MODELS_DIR}")
        return models
    
    # Checkpoints (main models)
    checkpoints_dir = os.path.join(COMFYUI_MODELS_DIR, "checkpoints")
    if os.path.exists(checkpoints_dir):
        for subdir in os.listdir(checkpoints_dir):
            subdir_path = os.path.join(checkpoints_dir, subdir)
            if os.path.isdir(subdir_path):
                for file in os.listdir(subdir_path):
                    if file.endswith(('.safetensors', '.ckpt', '.bin')):
                        models["checkpoints"].append(f"{subdir}/{file}")
    
    # LoRAs
    loras_dir = os.path.join(COMFYUI_MODELS_DIR, "loras")
    if os.path.exists(loras_dir):
        for subdir in os.listdir(loras_dir):
            subdir_path = os.path.join(loras_dir, subdir)
            if os.path.isdir(subdir_path):
                for file in os.listdir(subdir_path):
                    if file.endswith(('.safetensors', '.ckpt')):
                        models["loras"].append(f"{subdir}/{file}")
    
    # ControlNet models
    controlnet_dir = os.path.join(COMFYUI_MODELS_DIR, "controlnet")
    if os.path.exists(controlnet_dir):
        for subdir in os.listdir(controlnet_dir):
            subdir_path = os.path.join(controlnet_dir, subdir)
            if os.path.isdir(subdir_path):
                for file in os.listdir(subdir_path):
                    if file.endswith(('.safetensors', '.ckpt')):
                        models["controlnet"].append(f"{subdir}/{file}")
    
    # VAE models
    vae_dir = os.path.join(COMFYUI_MODELS_DIR, "vae")
    if os.path.exists(vae_dir):
        for subdir in os.listdir(vae_dir):
            subdir_path = os.path.join(vae_dir, subdir)
            if os.path.isdir(subdir_path):
                for file in os.listdir(subdir_path):
                    if file.endswith(('.safetensors', '.ckpt')):
                        models["vae"].append(f"{subdir}/{file}")
    
    # Embeddings
    embeddings_dir = os.path.join(COMFYUI_MODELS_DIR, "embeddings")
    if os.path.exists(embeddings_dir):
        for subdir in os.listdir(embeddings_dir):
            subdir_path = os.path.join(embeddings_dir, subdir)
            if os.path.isdir(subdir_path):
                for file in os.listdir(subdir_path):
                    if file.endswith(('.safetensors', '.bin')):
                        models["embeddings"].append(f"{subdir}/{file}")
    
    # Upscale models
    upscale_dir = os.path.join(COMFYUI_MODELS_DIR, "upscale_models")
    if os.path.exists(upscale_dir):
        for file in os.listdir(upscale_dir):
            if file.endswith(('.safetensors', '.ckpt', '.pth')):
                models["upscale_models"].append(file)
    
    return models

def find_model_path(model_name: str) -> Optional[str]:
    """Find the full path to a model in the ComfyUI directory structure."""
    if not os.path.exists(COMFYUI_MODELS_DIR):
        return None
    
    # Check if it's a path with subdirectory (e.g., "SD1.5/v1-5-pruned-emaonly.ckpt")
    if "/" in model_name:
        # Check in checkpoints directory first
        checkpoints_dir = os.path.join(COMFYUI_MODELS_DIR, "checkpoints")
        if os.path.exists(checkpoints_dir):
            model_path = os.path.join(checkpoints_dir, model_name)
            if os.path.exists(model_path):
                return model_path
        
        # Check if it's a direct path in the models directory
        direct_path = os.path.join(COMFYUI_MODELS_DIR, model_name)
        if os.path.exists(direct_path):
            return direct_path
        
        # If not found locally, return as-is for HuggingFace models
        return model_name
    
    # For simple model names, search in checkpoints directory
    checkpoints_dir = os.path.join(COMFYUI_MODELS_DIR, "checkpoints")
    if os.path.exists(checkpoints_dir):
        for subdir in os.listdir(checkpoints_dir):
            subdir_path = os.path.join(checkpoints_dir, subdir)
            if os.path.isdir(subdir_path):
                # Check for exact match
                model_path = os.path.join(subdir_path, model_name)
                if os.path.exists(model_path):
                    return model_path
                
                # Check for match without extension
                for file in os.listdir(subdir_path):
                    if file.startswith(model_name) and file.endswith(('.safetensors', '.ckpt', '.bin')):
                        return os.path.join(subdir_path, file)
    
    # Check if it's a direct path
    direct_path = os.path.join(COMFYUI_MODELS_DIR, model_name)
    if os.path.exists(direct_path):
        return direct_path
    
    return None

def load_model(model_name: str):
    """Load a Stable Diffusion model from ComfyUI directory."""
    global pipeline, models_cache
    
    if model_name in models_cache:
        return models_cache[model_name]
    
    # Find the model path
    model_path = find_model_path(model_name)
    if not model_path:
        # Try to load from HuggingFace hub
        model_path = model_name
    
    try:
        logger.info(f"Loading model: {model_path}")
        
        # Check if it's a .ckpt file
        if model_path.endswith('.ckpt'):
            logger.info(f"Converting checkpoint file: {model_path}")
            # Convert checkpoint to diffusers format with safe globals
            with torch.serialization.safe_globals(['pytorch_lightning.callbacks.model_checkpoint.ModelCheckpoint']):
                pipeline = download_from_original_stable_diffusion_ckpt(
                    checkpoint_path_or_dict=model_path,
                    from_safetensors=False,
                    load_safety_checker=False,
                    extract_ema=True,
                    device="cuda" if torch.cuda.is_available() else "cpu",
                    local_files_only=True
                )
        else:
            # Load the pipeline normally
            pipeline = StableDiffusionPipeline.from_pretrained(
                model_path,
                torch_dtype=torch.float32,  # Use float32 for higher GPU utilization
                safety_checker=None,
                requires_safety_checker=False
            )
        
        # Move to GPU if available
        if torch.cuda.is_available():
            pipeline = pipeline.to("cuda")
            logger.info("Model loaded on GPU")
        else:
            logger.info("Model loaded on CPU")
        
        # Set scheduler
        pipeline.scheduler = DPMSolverMultistepScheduler.from_config(pipeline.scheduler.config)
        
        models_cache[model_name] = pipeline
        return pipeline
        
    except Exception as e:
        logger.error(f"Failed to load model {model_name}: {str(e)}")
        raise

async def generate_image_task(task: GenerationTask):
    """Background task to generate an image."""
    global pipeline
    
    try:
        task.status = "processing"
        task.start_time = time.time()
        
        # Load model if not already loaded
        pipeline = load_model(task.request.model)
        
        # Set seed
        if task.request.seed == -1:
            seed = torch.randint(0, 2**32 - 1, (1,)).item()
        else:
            seed = task.request.seed
        
        torch.manual_seed(seed)
        
        # Generate image
        logger.info(f"Generating image for task {task.task_id}")
        
        with torch.no_grad():
            result = pipeline(
                prompt=task.request.prompt,
                negative_prompt=task.request.negative_prompt,
                width=task.request.width,
                height=task.request.height,
                num_inference_steps=task.request.steps,
                guidance_scale=task.request.cfg_scale,
                generator=torch.Generator(device=pipeline.device).manual_seed(seed)
            )
        
        # Save image
        image = result.images[0]
        image_filename = f"{task.task_id}.png"
        image_path = os.path.join(OUTPUT_DIR, image_filename)
        image.save(image_path)
        
        # Convert to base64 for API response
        import io
        img_buffer = io.BytesIO()
        image.save(img_buffer, format='PNG')
        img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
        
        task.end_time = time.time()
        task.status = "completed"
        task.progress = 100
        
        task.result = {
            "image_url": f"/images/{image_filename}",
            "image_data": img_base64,
            "generation_time": f"{task.end_time - task.start_time:.2f}s",
            "model_version": task.request.model,
            "seed": seed
        }
        
        logger.info(f"Image generation completed for task {task.task_id}")
        
    except Exception as e:
        task.status = "failed"
        task.error = str(e)
        logger.error(f"Image generation failed for task {task.task_id}: {str(e)}")

@app.on_event("startup")
async def startup_event():
    """Initialize the service on startup."""
    logger.info("Starting Image Generation Service")
    logger.info(f"ComfyUI models directory: {COMFYUI_MODELS_DIR}")
    logger.info(f"Output directory: {OUTPUT_DIR}")
    
    # Check for available models
    models = get_available_models()
    total_models = sum(len(model_list) for model_list in models.values())
    logger.info(f"Found {total_models} models in ComfyUI directory")
    
    # Log model counts by type
    for model_type, model_list in models.items():
        if model_list:
            logger.info(f"  {model_type}: {len(model_list)} models")
    
    # Check GPU availability
    if torch.cuda.is_available():
        logger.info(f"GPU available: {torch.cuda.get_device_name(0)}")
        logger.info(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
    else:
        logger.warning("No GPU available, using CPU")

@app.get("/")
async def root():
    """Health check endpoint."""
    models = get_available_models()
    total_models = sum(len(model_list) for model_list in models.values())
    
    return {
        "service": "Image Generation Service",
        "status": "running",
        "gpu_available": torch.cuda.is_available(),
        "models_loaded": list(models_cache.keys()),
        "total_models_found": total_models,
        "comfyui_models_dir": COMFYUI_MODELS_DIR
    }

@app.get("/models")
async def list_models():
    """List available models from ComfyUI directory."""
    models = get_available_models()
    return {
        "available_models": models,
        "loaded_models": list(models_cache.keys()),
        "comfyui_models_dir": COMFYUI_MODELS_DIR
    }

@app.get("/models/checkpoints")
async def list_checkpoints():
    """List available checkpoint models."""
    models = get_available_models()
    return {
        "checkpoints": models["checkpoints"],
        "total": len(models["checkpoints"])
    }

@app.post("/generate")
async def generate_image(request: GenerationRequest, background_tasks: BackgroundTasks):
    """Start an image generation task."""
    task_id = str(uuid.uuid4())
    task = GenerationTask(task_id, request)
    tasks[task_id] = task
    
    # Start background task
    background_tasks.add_task(generate_image_task, task)
    
    logger.info(f"Started generation task {task_id} for prompt: {request.prompt[:50]}...")
    
    return {
        "task_id": task_id,
        "status": "started",
        "message": "Image generation started"
    }

@app.get("/status/{task_id}")
async def get_status(task_id: str):
    """Get the status of a generation task."""
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks[task_id]
    return {
        "task_id": task_id,
        "status": task.status,
        "progress": task.progress,
        "error": task.error
    }

@app.get("/result/{task_id}")
async def get_result(task_id: str):
    """Get the result of a completed generation task."""
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks[task_id]
    
    if task.status == "completed":
        return task.result
    elif task.status == "failed":
        raise HTTPException(status_code=400, detail=f"Generation failed: {task.error}")
    else:
        raise HTTPException(status_code=202, detail="Task still processing")

@app.get("/images/{filename}")
async def get_image(filename: str):
    """Serve generated images."""
    image_path = os.path.join(OUTPUT_DIR, filename)
    if not os.path.exists(image_path):
        raise HTTPException(status_code=404, detail="Image not found")
    
    from fastapi.responses import FileResponse
    return FileResponse(image_path)

@app.delete("/tasks/{task_id}")
async def cancel_task(task_id: str):
    """Cancel a generation task."""
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks[task_id]
    if task.status in ["pending", "processing"]:
        task.status = "cancelled"
        return {"message": "Task cancelled"}
    else:
        raise HTTPException(status_code=400, detail="Cannot cancel completed or failed task")

if __name__ == "__main__":
    # Get configuration from environment
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    
    logger.info(f"Starting server on {host}:{port}")
    uvicorn.run(app, host=host, port=port) 