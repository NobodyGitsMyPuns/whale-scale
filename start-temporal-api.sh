#!/bin/bash

# Start Temporal API Server script
TEMPORAL_API_PORT=${1:-8002}
TEMPORAL_SERVER_PORT=${2:-7233}
IMAGE_SERVICE_PORT=${3:-8000}
VENV_PATH=${4:-/tmp/whale-scale-venv}

echo "🔗 Starting Temporal API server on port $TEMPORAL_API_PORT..."
echo "   Connecting to Temporal server: localhost:$TEMPORAL_SERVER_PORT"
echo "   Image service URL: http://localhost:$IMAGE_SERVICE_PORT"

# Kill any existing Temporal API server
pkill -f "temporal_api_server.py" 2>/dev/null || true
sleep 1

# Set up virtual environment if needed
if [ ! -d "$VENV_PATH" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv $VENV_PATH
    . $VENV_PATH/bin/activate && pip install --upgrade pip
    . $VENV_PATH/bin/activate && pip install -r requirements.txt
fi

# Start the Temporal API server
echo "🚀 Starting Temporal API server..."
. $VENV_PATH/bin/activate && \
TEMPORAL_TARGET=localhost:$TEMPORAL_SERVER_PORT \
IMAGE_SERVICE_URL=http://localhost:$IMAGE_SERVICE_PORT \
python3 temporal_api_server.py > /dev/null 2>&1 &

SERVER_PID=$!
sleep 3

# Check if the server is running
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "✅ Temporal API server started successfully!"
    echo "🌐 Access it at: http://localhost:$TEMPORAL_API_PORT"
    echo "🏥 Health check: http://localhost:$TEMPORAL_API_PORT/health"
    echo "📝 Server PID: $SERVER_PID"
    
    # Test the health endpoint
    sleep 2
    if curl -s http://localhost:$TEMPORAL_API_PORT/health > /dev/null; then
        echo "✅ Health check passed - API server is responding"
    else
        echo "⚠️  Server started but health check failed"
    fi
else
    echo "❌ Failed to start Temporal API server"
    exit 1
fi 