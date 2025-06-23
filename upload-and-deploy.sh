#!/bin/bash

# Script upload code local lên server và deploy
# Usage: ./upload-and-deploy.sh

set -e

SERVER_IP="207.180.251.81"
SERVER_USER="root"
PROJECT_DIR="/var/www/twitter-oauth-backend"

echo "🚀 Starting upload and deployment to server $SERVER_IP..."

# Tạo thư mục temp để archive
echo "📦 Creating archive..."
tar --exclude='.git' \
    --exclude='node_modules' \
    --exclude='*.tar.gz' \
    --exclude='.env' \
    -czf twitter-oauth-backend.tar.gz \
    --transform 's,^,twitter-oauth-backend/,' \
    Dockerfile docker-compose*.yml package*.json server.js .dockerignore nginx.conf *.md

echo "📤 Uploading to server..."
scp twitter-oauth-backend.tar.gz $SERVER_USER@$SERVER_IP:/tmp/

echo "🔧 Deploying on server..."
ssh $SERVER_USER@$SERVER_IP << 'ENDSSH'
set -e

echo "📂 Preparing project directory..."
rm -rf /var/www/twitter-oauth-backend
mkdir -p /var/www/twitter-oauth-backend
cd /var/www/twitter-oauth-backend

echo "📥 Extracting archive..."
tar -xzf /tmp/twitter-oauth-backend.tar.gz --strip-components=1
rm /tmp/twitter-oauth-backend.tar.gz

echo "⚙️ Creating .env file..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=3001
TWITTER_CLIENT_ID=T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ
TWITTER_CLIENT_SECRET=9R8RECRDHOuFpZCT_7U4FwrPYI4WjAGllHmJq52
TWITTER_REDIRECT_URI=https://your-frontend-domain.com/auth/twitter/callback
FIRESTARTER_API_BASE_URL=https://api2.khanhdev.tech/api/v1/trustcore
EOF

chmod 600 .env

echo "🛑 Stopping existing container..."
if [ "$(docker ps -aq -f name=twitter-oauth-backend)" ]; then
    docker stop twitter-oauth-backend || true
    docker rm twitter-oauth-backend || true
fi

echo "🔨 Building Docker image..."
docker build -t twitter-oauth-backend .

echo "🚀 Starting container..."
docker run -d \
  --name twitter-oauth-backend \
  --restart unless-stopped \
  -p 3001:3001 \
  --env-file .env \
  twitter-oauth-backend

echo "⏳ Waiting for startup..."
sleep 15

echo "🔍 Health check..."
if docker exec twitter-oauth-backend curl -f http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo "🌐 API: http://207.180.251.81:3001"
    echo "🔗 Health: http://207.180.251.81:3001/health"
else
    echo "❌ Health check failed!"
    docker logs twitter-oauth-backend
fi

echo "📊 Container status:"
docker ps | grep twitter-oauth-backend

echo "🎉 Done!"
ENDSSH

# Cleanup local archive
rm -f twitter-oauth-backend.tar.gz

echo "🏁 Upload and deployment completed!"
