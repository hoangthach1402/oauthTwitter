#!/bin/bash

# One-liner deployment script
# Đơn giản chỉ cần chạy script này

echo "🚀 Starting simple deployment..."

# Upload current directory to server
echo "📤 Uploading files..."
rsync -avz --exclude='.git' --exclude='node_modules' --exclude='*.tar.gz' \
    ./ root@207.180.251.81:/var/www/twitter-oauth-backend/

# Deploy on server
echo "🔧 Deploying..."
ssh root@207.180.251.81 '
cd /var/www/twitter-oauth-backend

# Create .env
cat > .env << "EOF"
NODE_ENV=production
PORT=3001
TWITTER_CLIENT_ID=T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ
TWITTER_CLIENT_SECRET=9R8RECRDHOuFpZCT_7U4FwrPYI4WjAGllHmJq52
TWITTER_REDIRECT_URI=https://your-frontend-domain.com/auth/twitter/callback
FIRESTARTER_API_BASE_URL=https://api-firestarter.earnai.art/api/v1/trustcore
EOF

# Stop old container
docker stop twitter-oauth-backend 2>/dev/null || true
docker rm twitter-oauth-backend 2>/dev/null || true

# Build and run
docker build -t twitter-oauth-backend .
docker run -d --name twitter-oauth-backend --restart unless-stopped -p 3001:3001 --env-file .env twitter-oauth-backend

# Check status
sleep 10
docker ps | grep twitter-oauth-backend
echo "✅ Deployment done! API at: http://207.180.251.81:3001"
'

echo "🎉 Script completed!"
