import asyncio
from temporalio.client import Client
from .workflows import HelloWorkflow

async def main():
    client = await Client.connect("localhost:7233")
    result = await client.execute_workflow(HelloWorkflow.run, "Jesse", id="your-workflow-id")
    print(f"Workflow returned: {result}")

if __name__ == "__main__":
    asyncio.run(main())