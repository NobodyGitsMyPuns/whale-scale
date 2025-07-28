import asyncio
import argparse
from temporalio.client import Client
from .workflows import HelloWorkflow, HealthCheckWorkflow, Text2ImageWorkflow, WorkflowType

async def main():
    parser = argparse.ArgumentParser(description="Start Temporal workflows")
    parser.add_argument("--type", type=str, choices=[t.value for t in WorkflowType], 
                       default="hello", help="Type of workflow to start")
    parser.add_argument("--name", type=str, default="World", 
                       help="Name for hello workflow")
    parser.add_argument("--containers", type=str, nargs="+", 
                       default=["whale-scale-worker-1"], 
                       help="Container names for health check")
    parser.add_argument("--prompt", type=str, 
                       default="A majestic whale swimming in the deep ocean, high quality, detailed", 
                       help="Text prompt for image generation")
    parser.add_argument("--negative-prompt", type=str, default="blurry, low quality, distorted", 
                       help="Negative prompt for image generation")
    parser.add_argument("--model", type=str, default="runwayml/stable-diffusion-v1-5", 
                       help="Model for image generation (e.g., 'runwayml/stable-diffusion-v1-5', 'FLUX1/flux1-schnell-fp8.safetensors')")
    parser.add_argument("--width", type=int, default=512, 
                       help="Image width")
    parser.add_argument("--height", type=int, default=512, 
                       help="Image height")
    parser.add_argument("--steps", type=int, default=20, 
                       help="Number of inference steps")
    parser.add_argument("--cfg-scale", type=float, default=7.5, 
                       help="CFG scale for guidance")
    parser.add_argument("--seed", type=int, default=None, 
                       help="Random seed (use -1 for random)")
    parser.add_argument("--id", type=str, help="Custom workflow ID")
    
    args = parser.parse_args()

    # Connect to the Temporal server
    client = await Client.connect("localhost:7233")
    
    workflow_type = WorkflowType(args.type)
    
    if workflow_type == WorkflowType.HELLO:
        # Execute HelloWorkflow
        workflow_id = args.id or f"hello-workflow-{args.name}"
        result = await client.execute_workflow(
            HelloWorkflow.run,
            args.name,
            id=workflow_id,
            task_queue="hello-python-tq",
        )
        print(f"HelloWorkflow result: {result}")
        
    elif workflow_type == WorkflowType.HEALTH_CHECK:
        # Execute HealthCheckWorkflow
        workflow_id = args.id or f"health-check-{'-'.join(args.containers)}"
        result = await client.execute_workflow(
            HealthCheckWorkflow.run,
            args.containers,
            id=workflow_id,
            task_queue="hello-python-tq",
        )
        print("HealthCheckWorkflow result:")
        print(json.dumps(result, indent=2))
        
    elif workflow_type == WorkflowType.TEXT2IMAGE:
        # Execute Text2ImageWorkflow
        workflow_id = args.id or f"text2image-{hash(args.prompt) % 10000}"
        result = await client.execute_workflow(
            Text2ImageWorkflow.run,
            (args.prompt, args.model, args.negative_prompt, args.width, args.height, args.steps, args.cfg_scale, args.seed),
            id=workflow_id,
            task_queue="hello-python-tq",
        )
        print("Text2ImageWorkflow result:")
        print(json.dumps(result, indent=2))

if __name__ == "__main__":
    import json
    asyncio.run(main())