import asyncio
import os
import signal
import sys
from temporalio.client import Client
from temporalio.worker import Worker
from .workflows import HelloWorkflow
from .activities import say_hello

# Try to use uvloop if available for better performance
try:
    import uvloop
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    print("Using uvloop for improved performance")
except ImportError:
    print("uvloop not available, using standard event loop")

async def main():
    # Get configuration from environment variables with defaults
    temporal_target = os.environ.get("TEMPORAL_TARGET", "localhost:7233")
    task_queue = os.environ.get("TASK_QUEUE", "hello-python-tq")
    
    # Print startup information
    print(f"Connecting to Temporal server at {temporal_target}")
    print(f"Using task queue: {task_queue}")
    
    # Connect to the Temporal server
    client = await Client.connect(temporal_target)
    
    # Create a worker that hosts workflow and activity implementations
    worker = Worker(
        client, 
        task_queue=task_queue, 
        workflows=[HelloWorkflow], 
        activities=[say_hello]
    )
    
    # Set up graceful shutdown
    shutdown_event = asyncio.Event()
    
    def handle_signal(sig, frame):
        print(f"Received signal {sig}, shutting down...")
        shutdown_event.set()
    
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)
    
    # Start the worker
    print("Starting worker...")
    await worker.run()

if __name__ == "__main__":
    asyncio.run(main())