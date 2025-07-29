#!/bin/bash

# Stop admin interface script
ADMIN_PORT=${1:-8080}

echo "🛑 Stopping admin interface on port $ADMIN_PORT..."

# Kill any existing HTTP server on this port
if pkill -f "http.server.*$ADMIN_PORT" 2>/dev/null; then
    echo "✅ Admin interface stopped"
else
    echo "ℹ️  No admin interface was running on port $ADMIN_PORT"
fi 