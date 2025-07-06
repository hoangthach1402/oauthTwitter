#!/bin/bash

# Update VPS with clean Docker Compose files (no warnings)
# This script removes environment variable references and version attribute

echo "🚀 Updating VPS Docker Compose files..."

# Define VPS details
VPS_HOST="root@45.76.163.108"
VPS_PROJECT_DIR="/var/www/oauthTwitter"

# Upload updated compose files
echo "📁 Uploading updated docker-compose files..."
scp docker-compose.yml ${VPS_HOST}:${VPS_PROJECT_DIR}/
scp docker-compose.prod.yml ${VPS_HOST}:${VPS_PROJECT_DIR}/
scp docker-compose.dev.yml ${VPS_HOST}:${VPS_PROJECT_DIR}/

# SSH into VPS and rebuild
echo "🔧 Rebuilding and restarting containers on VPS..."
ssh ${VPS_HOST} << 'EOF'
cd /var/www/oauthTwitter

echo "Stopping existing containers..."
docker-compose down --remove-orphans

echo "Removing old images..."
docker image prune -f

echo "Building new image..."
docker-compose build --no-cache

echo "Starting containers with updated compose file..."
docker-compose up -d

echo "Checking container status..."
docker-compose ps

echo "Checking logs for any errors..."
docker-compose logs --tail=20

echo "Testing health endpoint..."
sleep 5
curl -f http://localhost:3001/health || echo "Health check failed"

echo "✅ VPS update complete!"
EOF

echo "🎉 VPS update finished! Check the output above for any issues."
