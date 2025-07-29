#!/usr/bin/env python3
"""
Temporal API Server - HTTP API for triggering Temporal workflows
This server acts as a bridge between the admin interface and Temporal workflows
"""

import asyncio
import json
import uuid
from datetime import datetime
from typing import Dict, Any
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from temporalio.client import Client

# Import the starter module
from app.starter import main as start_workflow
from app.workflows import Text2ImageWorkflow

app = FastAPI(title="Temporal API Server", version="1.0.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store workflow status
workflow_status: Dict[str, Dict[str, Any]] = {}

class ImageGenerationRequest(BaseModel):
    prompt: str
    negative_prompt: str = "blurry, distorted, low quality, low resolution, poorly drawn, bad anatomy, disfigured, deformed, extra limbs, mutated, watermark, text, signature, nsfw, grainy, noisy, overexposed, underexposed, ugly"
    model: str = "runwayml/stable-diffusion-v1-5"
    width: int = 512
    height: int = 512
    steps: int = 20
    cfg_scale: float = 7.5
    seed: int = -1

@app.get("/")
async def root():
    return {
        "service": "Temporal API Server",
        "status": "running",
        "description": "HTTP API for triggering Temporal workflows",
        "endpoints": {
            "POST /generate": "Start image generation workflow",
            "GET /status/{workflow_id}": "Get workflow status",
            "GET /workflows": "List all workflows"
        }
    }

@app.post("/generate")
async def generate_image(request: ImageGenerationRequest):
    """Start a Temporal workflow for image generation"""
    try:
        # Generate unique workflow ID
        workflow_id = f"text2image-{uuid.uuid4().hex[:8]}"
        
        # Store initial status
        workflow_status[workflow_id] = {
            "workflow_id": workflow_id,
            "status": "starting",
            "created_at": datetime.now().isoformat(),
            "request": request.model_dump(),
            "result": None,
            "error": None
        }
        
        # Start workflow in background
        asyncio.create_task(run_workflow(workflow_id, request))
        
        return {
            "task_id": workflow_id,
            "workflow_id": workflow_id,
            "status": "starting",
            "message": "Workflow started successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start workflow: {str(e)}")

async def run_workflow(workflow_id: str, request: ImageGenerationRequest):
    """Run the Temporal workflow in background"""
    try:
        # Update status to running
        workflow_status[workflow_id]["status"] = "running"
        workflow_status[workflow_id]["started_at"] = datetime.now().isoformat()
        
        # Connect to Temporal
        client = await Client.connect("localhost:7233")
        
        # Start workflow (queues it for worker to pick up)
        handle = await client.start_workflow(
            Text2ImageWorkflow.run,
            (request.prompt, request.model, request.negative_prompt, 
             request.width, request.height, request.steps, request.cfg_scale, request.seed),
            id=workflow_id,
            task_queue="hello-python-tq",
        )
        
        # Wait for workflow completion
        result = await handle.result()
        
        # Update status to completed
        workflow_status[workflow_id]["status"] = "completed"
        workflow_status[workflow_id]["completed_at"] = datetime.now().isoformat()
        workflow_status[workflow_id]["result"] = result
        
    except Exception as e:
        # Update status to failed
        workflow_status[workflow_id]["status"] = "failed"
        workflow_status[workflow_id]["failed_at"] = datetime.now().isoformat()
        workflow_status[workflow_id]["error"] = str(e)

@app.get("/status/{workflow_id}")
async def get_workflow_status(workflow_id: str):
    """Get the status of a workflow"""
    if workflow_id not in workflow_status:
        raise HTTPException(status_code=404, detail="Workflow not found")
    
    return workflow_status[workflow_id]

@app.get("/result/{workflow_id}")
async def get_workflow_result(workflow_id: str):
    """Get the result of a completed workflow"""
    if workflow_id not in workflow_status:
        raise HTTPException(status_code=404, detail="Workflow not found")
    
    workflow = workflow_status[workflow_id]
    if workflow["status"] != "completed":
        raise HTTPException(status_code=400, detail="Workflow not completed")
    
    # Return the result in the format expected by the admin interface
    if workflow["result"]:
        return {
            "image_data": workflow["result"].get("image_data", ""),
            "generation_time": workflow["result"].get("generation_time", ""),
            "model_version": workflow["result"].get("model_version", ""),
            "seed": workflow["result"].get("seed", ""),
            "workflow_id": workflow_id
        }
    else:
        raise HTTPException(status_code=404, detail="No result available")

@app.get("/workflows")
async def list_workflows():
    """List all workflows"""
    return {
        "workflows": list(workflow_status.values()),
        "total": len(workflow_status)
    }

@app.get("/models/text2image")
async def get_text2image_models():
    """Get available text2image models"""
    return {
        "available_models": {
            "checkpoints": [
                "runwayml/stable-diffusion-v1-5",
                "stabilityai/stable-diffusion-xl-base-1.0",
                "stabilityai/stable-diffusion-2-1"
            ],
            "loras": [],
            "controlnet": [],
            "vae": [],
            "embeddings": [],
            "upscale_models": []
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    print("Starting Temporal API Server...")
    print("This server bridges HTTP requests to Temporal workflows")
    print("Admin interface should point to this server instead of image service")
    uvicorn.run(app, host="0.0.0.0", port=8002) 