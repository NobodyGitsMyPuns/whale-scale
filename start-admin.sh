#!/bin/bash

# Start admin interface script
ADMIN_PORT=${1:-8080}

echo "🌐 Starting admin interface on port $ADMIN_PORT..."

# Kill any existing HTTP server on this port
pkill -f "http.server.*$ADMIN_PORT" 2>/dev/null || true
sleep 1

# Start the HTTP server in the background
python3 -m http.server $ADMIN_PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait a moment for the server to start
sleep 2

# Check if the server is running
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "✅ Admin interface started successfully!"
    echo "🌐 Access it at: http://localhost:$ADMIN_PORT/admin.html"
    echo "📝 Server PID: $SERVER_PID"
else
    echo "❌ Failed to start admin interface"
    exit 1
fi 