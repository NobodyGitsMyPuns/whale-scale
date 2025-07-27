import time
from temporalio import activity

@activity.defn
async def say_hello(name: str) -> str:
    # Simulate work that might fail
    for i in range(3):
        # Report progress via heartbeat
        activity.heartbeat(f"Processing step {i+1}/3")
        time.sleep(0.5)
    
    return f"Hello, {name}!"