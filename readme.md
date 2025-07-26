# Hello World Temporal App in Python with Kubernetes and NVIDIA GPU support

## Prerequisites
- Docker
- Docker Compose
- Python 3.7+
- Make (optional, but recommended)
- Kubectl
- Helm (for EKS/GKE/AKS deployment)

## Quickstart
1. Clone the repository: `git clone https://github.com/yourusername/whale-scale.git`
2. Create a Python virtual environment and install dependencies: 
```bash
python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```
3. Start the Temporal Server, Web UI, and Postgres using Docker Compose: `docker compose up -d`
4. Run the worker locally: `python -m app.worker`
5. In a separate terminal window, start a workflow run: `python -m app.starter --name "Jesse"`
6. View the Web UI at http://localhost:8233



2. `docker-compose.yml`:
```yaml
version: "3.9"
services:
  temporal:
    image: temporalio/auto-setup:1.7.0
    environment:
      - DATABASE=sqlite
      - DBNAME=temporal
      - ENABLE_ES=false
    ports:
      - "8233:8233"
      - "7233:7233"
```

3. `requirements.txt`:
```text
temporalio==1.6.0
uvloop==0.14.0
pytest==6.2.5
```

4. `app/workflows.py`:
```python
from temporalio import workflow

@workflow.defn
class HelloWorkflow:
    @workflow.run
    async def run(self, name: str) -> str:
        return f"Hello, {name}!"
```

5. `app/activities.py`:
```python
from temporalio import activity

@activity.defn
async def say_hello(name: str) -> str:
    return f"Hello, {name}!"
```

6. `app/worker.py`:
```python
import asyncio
from temporalio.client import Client
from temporalio.worker import Worker
from .workflows import HelloWorkflow
from .activities import say_hello

async def main():
    client = await Client.connect("localhost:7233")
    worker = Worker(client, task_queue="your-task-queue", workflows=[HelloWorkflow], activities=[say_hello])
    await worker.run()

if __name__ == "__main__":
    asyncio.run(main())
```

7. `app/starter.py`:
```python
import asyncio
from temporalio.client import Client
from .workflows import HelloWorkflow

async def main():
    client = await Client.connect("localhost:7233")
    result = await client.execute_workflow(HelloWorkflow.run, "Jesse", id="your-workflow-id")
    print(f"Workflow returned: {result}")

if __name__ == "__main__":
    asyncio.run(main())
```

8. `Dockerfile.worker`:
```dockerfile
FROM python:3.7
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "-m", "app.worker"]
```

9. `k8s/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: temporal
```

10. `k8s/configmap-env.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-vars
data:
  TEMPORAL_TARGET: "localhost:7233"
```

11. `k8s/deployment-worker.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporal-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - name: worker
        image: yourusername/whale-scale:latest
        envFrom:
        - configMapRef:
            name: env-vars
```

12. `k8s/service-account.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: temporal-worker
```

13. `nvidia/device-plugin-notes.md`:
```markdown
# NVIDIA Device Plugin for Kubernetes
The NVIDIA device plugin for Kubernetes is a DaemonSet that allows you to automatically:
- Expose the number of GPUs on each node of your cluster.
- Monitor and manage the lifecycle of GPUs.

To install it, run:
```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/daemonset/nvidia-device-plugin.yml
```
For more information, see the [official NVIDIA Device Plugin documentation](https://github.com/NVIDIA/k8s-device-plugin).
```

14. `.env.example`:
```text
TEMPORAL_TARGET=localhost:7233
```

15. `Makefile`:
```makefile
up:
	docker compose up -d
down:
	docker compose down
build-worker:
	docker build . -f Dockerfile.worker -t yourusername/whale-scale:latest
run-worker:
	python -m app.worker
start-workflow:
	python -m app.starter --name "Jesse"
```

Please replace `yourusername` with your actual GitHub username and update the Docker image name in `build-worker` and `deployment-worker.yaml` accordingly. Also, make sure to adjust the task queue and workflow ID in `app/starter.py` and `k8s/deployment-worker.yaml` respectively.