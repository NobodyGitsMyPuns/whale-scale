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