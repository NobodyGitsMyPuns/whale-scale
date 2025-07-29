#!/bin/bash

# Quick Deploy Script for Whale Scale
# This script provides the fastest way to redeploy your changes

set -e

echo "🐋 Whale Scale Quick Deploy"
echo "=========================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Function to show usage
show_usage() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  fast         - Fast redeploy (preserves dependencies) [DEFAULT]"
    echo "  local        - Deploy with local Temporal server"
    echo "  clean        - Clean cache and full redeploy"
    echo "  k8s          - Fast Kubernetes redeploy"
    echo "  status       - Show deployment status"
    echo "  help         - Show this help"
    echo ""
    echo "Examples:"
    echo "  ./quick-deploy.sh              # Fast Docker redeploy"
    echo "  ./quick-deploy.sh local        # Deploy with local Temporal"
    echo "  ./quick-deploy.sh clean        # Clean rebuild"
    echo "  ./quick-deploy.sh k8s          # Fast Kubernetes redeploy"
}

# Parse command line arguments
ACTION=${1:-fast}

case $ACTION in
    fast)
        echo "⚡ Starting fast Docker redeploy..."
        echo "This preserves dependency layers for faster builds."
        make restart
        ;;
    local)
        echo "🏠 Deploying with local Temporal server..."
        echo "This includes a local Temporal server and UI."
        ENVIRONMENT=local make startall
        ;;
    clean)
        echo "🧹 Performing clean redeploy..."
        echo "This will rebuild everything from scratch."
        make clean
        make startall
        ;;
    k8s)
        echo "☸️ Starting fast Kubernetes redeploy..."
        if ! command -v minikube &> /dev/null; then
            echo "❌ Minikube not found. Please install minikube for Kubernetes deployment."
            exit 1
        fi
        ENVIRONMENT=k8s make startall
        ;;
    status)
        echo "📊 Checking deployment status..."
        make status
        echo ""
        echo "🔍 Quick health check:"
        if curl -s http://localhost:8000/ > /dev/null; then
            echo "✅ Image Service is running on http://localhost:8000"
        else
            echo "❌ Image Service is not responding"
        fi
        
        if curl -s http://localhost:8233/ > /dev/null; then
            echo "✅ Temporal UI is running on http://localhost:8233"
        else
            echo "ℹ️  Temporal UI not running (use './quick-deploy.sh local' to start local Temporal)"
        fi
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "❌ Unknown option: $ACTION"
        echo ""
        show_usage
        exit 1
        ;;
esac

echo ""
echo "✅ Operation completed!"

# Show relevant URLs based on the action
case $ACTION in
    fast|clean)
        echo "🌐 Services:"
        echo "  - Image Service: http://localhost:8000"
        echo "  - Connect to external Temporal at: 172.21.181.91:7233"
        ;;
    local)
        echo "🌐 Services:"
        echo "  - Image Service: http://localhost:8000"
        echo "  - Temporal UI: http://localhost:8233"
        echo "  - Temporal Server: localhost:7233"
        ;;
    k8s)
        echo "🌐 Services running in Minikube cluster"
        echo "  - Check status: make status"
        echo "  - View logs: make logs-docker"
        ;;
esac

echo ""
echo "💡 Pro tips:"
echo "  - Use './quick-deploy.sh' for fastest redeploys"
echo "  - Use './quick-deploy.sh local' if Temporal connection fails"
echo "  - Use 'make help' to see all available commands" 