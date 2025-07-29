import asyncio
from enum import Enum
from temporalio import workflow, activity
from temporalio.common import RetryPolicy
from .activities import say_hello, check_container_health, generate_image_from_text
from datetime import timedelta

# Note: In Temporal 1.6.0, we rely on the SandboxRestriction.UNRESTRICTED setting in worker.py

class WorkflowType(Enum):
    HELLO = "hello"
    HEALTH_CHECK = "health_check"
    TEXT2IMAGE = "text2image"

@workflow.defn
class HelloWorkflow:
    def __init__(self):
        self._name = None
        self._suffix = "!"

    @workflow.run
    async def run(self, name: str) -> str:
        self._name = name
        return await workflow.execute_activity(
            say_hello,
            name,
            start_to_close_timeout=timedelta(seconds=10),
        )

    @workflow.signal
    def set_suffix(self, suffix: str):
        self._suffix = suffix

    @workflow.query
    def get_state(self) -> dict:
        return {
            "name": self._name,
            "suffix": self._suffix,
        }

@workflow.defn
class HealthCheckWorkflow:
    def __init__(self):
        self._containers = []
        self._health_results = {}

    @workflow.run
    async def run(self, containers: list[str]) -> dict:
        self._containers = containers
        health_results = {}
        
        # Check health of all containers in parallel
        tasks = []
        for container in containers:
            task = workflow.execute_activity(
                check_container_health,
                container,
                start_to_close_timeout=timedelta(seconds=30),
            )
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for i, container in enumerate(containers):
            if isinstance(results[i], Exception):
                health_results[container] = {
                    "status": "error",
                    "error": str(results[i])
                }
            else:
                health_results[container] = results[i]
        
        self._health_results = health_results
        return health_results

    @workflow.signal
    def add_container(self, container: str):
        """Add a container to check health for."""
        if container not in self._containers:
            self._containers.append(container)

    @workflow.query
    def get_health_status(self) -> dict:
        """Get current health status of all containers."""
        return {
            "containers": self._containers,
            "health_results": self._health_results,
            "summary": self._get_health_summary()
        }

    def _get_health_summary(self) -> dict:
        """Calculate health summary statistics."""
        if not self._health_results:
            return {"total": 0, "healthy": 0, "unhealthy": 0, "errors": 0}
        
        total = len(self._health_results)
        healthy = sum(1 for result in self._health_results.values() 
                     if result.get("status") == "healthy")
        unhealthy = sum(1 for result in self._health_results.values() 
                       if result.get("status") == "unhealthy")
        errors = sum(1 for result in self._health_results.values() 
                    if result.get("status") == "error")
        
        return {
            "total": total,
            "healthy": healthy,
            "unhealthy": unhealthy,
            "errors": errors
        }

@workflow.defn
class Text2ImageWorkflow:
    def __init__(self):
        self._prompt = ""
        self._image_url = None
        self._status = "pending"
        self._progress = 0

    @workflow.run
    async def run(self, args: tuple) -> dict:
        """
        Generate an image from text using the specified model.
        
        Args:
            args: Tuple containing (prompt, model, negative_prompt, width, height, steps, cfg_scale, seed)
            
        Returns:
            Dictionary containing the generation result
        """
        # Unpack the arguments
        prompt, model, negative_prompt, width, height, steps, cfg_scale, seed = args
        
        # Execute the image generation activity with retry policy
        retry_policy = RetryPolicy(
            initial_interval=timedelta(seconds=1),
            maximum_interval=timedelta(seconds=10),
            maximum_attempts=3,
            non_retryable_error_types=["ValueError", "KeyError"]
        )
        
        result = await workflow.execute_activity(
            generate_image_from_text,
            args,
            start_to_close_timeout=timedelta(minutes=10),
            retry_policy=retry_policy,
        )
        
        return result