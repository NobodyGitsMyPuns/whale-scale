import time
import subprocess
import json
import asyncio
import aiohttp
import base64
import os
import logging
from temporalio import activity

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@activity.defn
async def say_hello(name: str) -> str:
    """Simple hello activity with heartbeat."""
    activity.heartbeat()
    await asyncio.sleep(0.5)
    return f"Hello, {name}!"

@activity.defn
async def check_container_health(container_name: str) -> dict:
    """Check the health of a Docker container."""
    activity.heartbeat()
    
    try:
        # Check if container exists and get its status
        result = subprocess.run(
            ["docker", "inspect", container_name],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return {
                "status": "error",
                "error": f"Container {container_name} not found",
                "container": container_name
            }
        
        # Parse the container info
        container_info = json.loads(result.stdout)[0]
        state = container_info.get("State", {})
        
        # Check if container is running
        is_running = state.get("Running", False)
        exit_code = state.get("ExitCode", 0)
        
        # Get health check status if available
        health_status = "unknown"
        if "Health" in state:
            health_status = state["Health"].get("Status", "unknown")
        
        # Determine overall health
        if is_running and (health_status == "healthy" or health_status == "unknown"):
            status = "healthy"
        elif is_running and health_status == "unhealthy":
            status = "unhealthy"
        elif not is_running and exit_code == 0:
            status = "stopped"
        else:
            status = "unhealthy"
        
        return {
            "status": status,
            "container": container_name,
            "running": is_running,
            "exit_code": exit_code,
            "health_status": health_status,
            "started_at": state.get("StartedAt"),
            "finished_at": state.get("FinishedAt")
        }
        
    except subprocess.TimeoutExpired:
        return {
            "status": "error",
            "error": f"Timeout checking container {container_name}",
            "container": container_name
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "container": container_name
        }

@activity.defn
async def generate_image_from_text(args: tuple) -> dict:
    """Generate an image from text prompt using local GPU models via microservice."""
    # Unpack the arguments
    prompt, model, negative_prompt, width, height, steps, cfg_scale, seed = args
    
    # Set defaults if not provided
    model = model or "runwayml/stable-diffusion-v1-5"
    negative_prompt = negative_prompt or ""
    width = width or 512
    height = height or 512
    steps = steps or 30
    cfg_scale = cfg_scale or 5
    
    
    logger.info(f"Starting image generation activity with prompt: {prompt[:50]}...")
    activity.heartbeat()
    
    # Get microservice URL from environment or use default
    microservice_url = os.getenv("IMAGE_GENERATION_SERVICE_URL", "http://localhost:8000")
    logger.info(f"Using image generation service at: {microservice_url}")
    
    # Prepare the generation request
    generation_request = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "model": model,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "seed": seed if seed is not None else -1,  # -1 for random seed
        "sampler": "euler",  # Default sampler
        "scheduler": "normal"  # Default scheduler
    }
    
    logger.info(f"Generation request: {json.dumps(generation_request)}")
    
    try:
        async with aiohttp.ClientSession() as session:
            # Start generation
            activity.heartbeat()
            logger.info("Sending request to image generation service...")
            async with session.post(f"{microservice_url}/generate", 
                                   json=generation_request) as response:
                if response.status != 200:
                    error_text = await response.text()
                    logger.error(f"Generation request failed with status {response.status}: {error_text}")
                    raise Exception(f"Generation failed: {error_text}")
                
                result = await response.json()
                logger.info(f"Generation started with task_id: {result.get('task_id')}")
                
                # Poll for completion
                task_id = result.get("task_id")
                if not task_id:
                    logger.error("No task ID returned from generation service")
                    raise Exception("No task ID returned from generation service")
                
                # Poll for completion with progress updates
                while True:
                    activity.heartbeat()
                    await asyncio.sleep(1)  # Poll every second
                    
                    logger.info(f"Checking status for task {task_id}...")
                    async with session.get(f"{microservice_url}/status/{task_id}") as status_response:
                        if status_response.status != 200:
                            logger.error(f"Failed to get status with code {status_response.status}")
                            raise Exception("Failed to get generation status")
                        
                        status_data = await status_response.json()
                        status = status_data.get("status")
                        logger.info(f"Task {task_id} status: {status}, progress: {status_data.get('progress')}%")
                        
                        if status == "completed":
                            # Get the final result
                            logger.info(f"Task {task_id} completed, fetching result...")
                            async with session.get(f"{microservice_url}/result/{task_id}") as result_response:
                                if result_response.status != 200:
                                    logger.error(f"Failed to get result with code {result_response.status}")
                                    raise Exception("Failed to get generation result")
                                
                                final_result = await result_response.json()
                                logger.info(f"Successfully received result for task {task_id}")
                                
                                return {
                                    "image_url": final_result.get("image_url"),
                                    "image_data": final_result.get("image_data"),  # Base64 encoded
                                    "prompt": prompt,
                                    "model": model,
                                    "metadata": {
                                        "generation_time": final_result.get("generation_time"),
                                        "model_version": final_result.get("model_version"),
                                        "resolution": f"{width}x{height}",
                                        "steps": steps,
                                        "cfg_scale": cfg_scale,
                                        "seed": final_result.get("seed"),
                                        "sampler": "euler",
                                        "scheduler": "normal"
                                    }
                                }
                        
                        elif status == "failed":
                            error_msg = status_data.get("error", "Unknown error")
                            logger.error(f"Task {task_id} failed: {error_msg}")
                            raise Exception(f"Generation failed: {error_msg}")
                        
                        elif status == "processing" or status == "running":
                            # Continue polling
                            continue
                        
                        else:
                            logger.error(f"Unknown status: {status}")
                            raise Exception(f"Unknown status: {status}")
    
    except aiohttp.ClientError as e:
        logger.error(f"Network error: {str(e)}")
        raise Exception(f"Network error connecting to generation service: {str(e)}")
    except Exception as e:
        logger.error(f"Image generation failed: {str(e)}")
        raise Exception(f"Image generation failed: {str(e)}")