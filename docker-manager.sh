#!/bin/bash

# Docker Management Script for Twitter OAuth Backend
# Usage: ./docker-manager.sh [command]

set -e

PROJECT_NAME="twitter-oauth-backend"
COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Print usage
usage() {
    echo "Docker Manager for Twitter OAuth Backend"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build        Build Docker image"
    echo "  start        Start containers"
    echo "  stop         Stop containers"
    echo "  restart      Restart containers"
    echo "  logs         Show logs"
    echo "  status       Show container status"
    echo "  shell        Access container shell"
    echo "  clean        Clean up containers and images"
    echo "  health       Check application health"
    echo "  env          Show environment variables"
    echo "  deploy       Full deploy (build + start)"
    echo "  backup       Backup logs and config"
    echo "  update       Pull latest changes and redeploy"
    echo ""
}

# Check if .env file exists
check_env() {
    if [ ! -f .env ]; then
        print_color $RED "Error: .env file not found!"
        print_color $YELLOW "Please copy .env.example to .env and configure it:"
        print_color $BLUE "cp .env.example .env"
        exit 1
    fi
}

# Build Docker image
build() {
    print_color $BLUE "Building Docker image..."
    docker-compose build --no-cache
    print_color $GREEN "Build completed!"
}

# Start containers
start() {
    check_env
    print_color $BLUE "Starting containers..."
    docker-compose up -d
    print_color $GREEN "Containers started!"
    sleep 5
    status
}

# Stop containers
stop() {
    print_color $BLUE "Stopping containers..."
    docker-compose down
    print_color $GREEN "Containers stopped!"
}

# Restart containers
restart() {
    print_color $BLUE "Restarting containers..."
    stop
    start
}

# Show logs
logs() {
    docker-compose logs -f --tail=100
}

# Show container status
status() {
    print_color $BLUE "Container Status:"
    docker-compose ps
    echo ""
    print_color $BLUE "Resource Usage:"
    docker stats --no-stream $PROJECT_NAME 2>/dev/null || true
}

# Access container shell
shell() {
    print_color $BLUE "Accessing container shell..."
    docker exec -it $PROJECT_NAME sh
}

# Clean up
clean() {
    print_color $YELLOW "This will remove all containers and images. Continue? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_color $BLUE "Cleaning up..."
        docker-compose down --volumes --remove-orphans
        docker image prune -f
        docker container prune -f
        print_color $GREEN "Cleanup completed!"
    else
        print_color $YELLOW "Cleanup cancelled."
    fi
}

# Check application health
health() {
    print_color $BLUE "Checking application health..."
    
    # Check if container is running
    if ! docker-compose ps | grep -q "Up"; then
        print_color $RED "Container is not running!"
        return 1
    fi
    
    # Check health endpoint
    if curl -f -s http://localhost:3001/health > /dev/null; then
        print_color $GREEN "✓ Application is healthy!"
        
        # Show detailed health info
        echo ""
        print_color $BLUE "Health Check Response:"
        curl -s http://localhost:3001/health | jq . 2>/dev/null || curl -s http://localhost:3001/health
    else
        print_color $RED "✗ Application health check failed!"
        print_color $YELLOW "Checking logs..."
        docker-compose logs --tail=20 $PROJECT_NAME
        return 1
    fi
}

# Show environment variables
env_check() {
    print_color $BLUE "Environment Variables:"
    curl -s http://localhost:3001/debug/env 2>/dev/null || print_color $RED "Cannot access debug endpoint"
}

# Full deploy
deploy() {
    print_color $BLUE "Starting full deployment..."
    check_env
    build
    start
    health
    print_color $GREEN "Deployment completed successfully!"
}

# Backup logs and config
backup() {
    BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
    print_color $BLUE "Creating backup in $BACKUP_DIR..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup .env file (without secrets)
    cp .env.example "$BACKUP_DIR/"
    
    # Backup logs
    docker-compose logs > "$BACKUP_DIR/container_logs.txt" 2>/dev/null || true
    
    # Backup docker-compose config
    cp docker-compose.yml "$BACKUP_DIR/"
    cp Dockerfile "$BACKUP_DIR/"
    
    print_color $GREEN "Backup created in $BACKUP_DIR"
}

# Update and redeploy
update() {
    print_color $BLUE "Updating and redeploying..."
    
    # Pull latest changes (if in git repo)
    if [ -d .git ]; then
        print_color $BLUE "Pulling latest changes..."
        git pull
    fi
    
    # Rebuild and restart
    deploy
}

# Port management
check_port() {
    PORT=${1:-3001}
    print_color $BLUE "Checking port $PORT..."
    
    if lsof -Pi :$PORT -sTCP:LISTEN -t > /dev/null; then
        print_color $YELLOW "Port $PORT is in use:"
        lsof -Pi :$PORT -sTCP:LISTEN
        echo ""
        print_color $YELLOW "Kill process? (y/N)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            lsof -ti:$PORT | xargs kill -9
            print_color $GREEN "Process killed!"
        fi
    else
        print_color $GREEN "Port $PORT is available!"
    fi
}

# Main command handler
case "${1:-}" in
    "build")
        build
        ;;
    "start")
        start
        ;;
    "stop")
        stop
        ;;
    "restart")
        restart
        ;;
    "logs")
        logs
        ;;
    "status")
        status
        ;;
    "shell")
        shell
        ;;
    "clean")
        clean
        ;;
    "health")
        health
        ;;
    "env")
        env_check
        ;;
    "deploy")
        deploy
        ;;
    "backup")
        backup
        ;;
    "update")
        update
        ;;
    "port")
        check_port $2
        ;;
    *)
        usage
        ;;
esac
