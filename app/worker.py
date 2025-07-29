import asyncio
import os
import signal
import sys
from temporalio.client import Client
from temporalio.worker import Worker
from .workflows import HelloWorkflow, HealthCheckWorkflow, Text2ImageWorkflow
from .activities import say_hello, check_container_health, generate_image_from_text

# Try to import uvloop for better performance (optional)
try:
    import uvloop
    if sys.platform != "win32":
        uvloop.install()
        print("uvloop installed for better performance")
except ImportError:
    print("uvloop not available, using standard event loop")

async def main():
    # Get configuration from environment variables
    temporal_target = os.getenv("TEMPORAL_TARGET", "localhost:7233")
    task_queue = os.getenv("TASK_QUEUE", "hello-python-tq")
    
    print(f"Connecting to Temporal server at {temporal_target}")
    print(f"Using task queue: {task_queue}")
    
    # Connect to the Temporal server
    client = await Client.connect(temporal_target)
    
    # Create a worker with unrestricted sandbox for file system operations
    os.environ["TEMPORAL_SANDBOX_UNRESTRICTED"] = "1"
    
    worker = Worker(
        client,
        task_queue=task_queue,
        workflows=[
            HelloWorkflow,
            HealthCheckWorkflow,
            Text2ImageWorkflow
        ],
        activities=[
            say_hello,
            check_container_health,
            generate_image_from_text
        ],
    )
    
    print("Starting worker with unrestricted sandbox...")
    
    # Set up graceful shutdown
    shutdown_event = asyncio.Event()
    
    def signal_handler(signum, frame):
        print(f"\nReceived signal {signum}, shutting down gracefully...")
        shutdown_event.set()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Run the worker until shutdown signal
    try:
        await worker.run()
    except KeyboardInterrupt:
        print("Worker stopped by user")
    except Exception as e:
        print(f"Worker error: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())