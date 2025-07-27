import asyncio
import argparse
from temporalio.client import Client
from .workflows import HelloWorkflow

async def main():
    parser = argparse.ArgumentParser(description="Start a HelloWorkflow")
    parser.add_argument("--name", type=str, default="World", help="Name to greet")
    args = parser.parse_args()

    # Connect to the Temporal server
    client = await Client.connect("localhost:7233")
    
    # Execute a workflow
    workflow_id = f"hello-workflow-{args.name}"
    result = await client.execute_workflow(
        HelloWorkflow.run,
        args.name,
        id=workflow_id,
        task_queue="hello-python-tq",
    )
    
    print(f"Workflow result: {result}")

if __name__ == "__main__":
    asyncio.run(main())