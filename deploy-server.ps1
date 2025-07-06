# Script PowerShell để deploy Twitter OAuth Backend lên server
# Usage: .\deploy-server.ps1

param(
    [string]$ServerIP = "207.180.251.81",
    [string]$ServerUser = "root"
)

Write-Host "🚀 Starting deployment to server $ServerIP..." -ForegroundColor Green

# Tạo script để chạy trên server
$remoteScript = @"
set -e

echo "📂 Creating project directory..."
mkdir -p /var/www/twitter-oauth-backend
cd /var/www/twitter-oauth-backend

echo "📥 Cloning repository..."
if [ -d ".git" ]; then
    echo "Repository exists, pulling latest changes..."
    git pull origin main
else
    echo "Cloning fresh repository..."
    git clone https://github.com/hoangthach1402/oauthTwitter.git .
fi

echo "⚙️ Creating .env file..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=3001
TWITTER_CLIENT_ID=T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ
TWITTER_CLIENT_SECRET=9R8RECRDHOuFpZCT_7U4FwrPYI4WjAGllHmJq52
TWITTER_REDIRECT_URI=https://your-frontend-domain.com/auth/twitter/callback
FIRESTARTER_API_BASE_URL=https://api-firestarter.earnai.art/api/v1/trustcore
EOF

chmod 600 .env

echo "🛑 Stopping existing container if any..."
if [ "`$(docker ps -aq -f name=twitter-oauth-backend)`" ]; then
    docker stop twitter-oauth-backend || true
    docker rm twitter-oauth-backend || true
fi

echo "🔨 Building Docker image..."
docker build -t twitter-oauth-backend .

echo "🚀 Starting new container..."
docker run -d \
  --name twitter-oauth-backend \
  --restart unless-stopped \
  -p 3001:3001 \
  --env-file .env \
  twitter-oauth-backend

echo "⏳ Waiting for container to start..."
sleep 15

echo "🔍 Checking health..."
if docker exec twitter-oauth-backend curl -f http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo "🌐 API available at: http://207.180.251.81:3001"
    echo "🔗 Health check: http://207.180.251.81:3001/health"
else
    echo "❌ Health check failed! Checking logs..."
    docker logs twitter-oauth-backend
fi

echo "🧹 Cleaning up old Docker images..."
docker image prune -f

echo "📊 Container status:"
docker ps | grep twitter-oauth-backend

echo "🎉 Deployment completed!"
"@

try {
    Write-Host "📡 Connecting to server..." -ForegroundColor Yellow
    
    # Thực hiện SSH và chạy script
    ssh "$ServerUser@$ServerIP" $remoteScript
    
    Write-Host "🏁 Deployment finished successfully!" -ForegroundColor Green
    Write-Host "🌐 Your API is now available at: http://$ServerIP`:3001" -ForegroundColor Cyan
    Write-Host "🔗 Health check: http://$ServerIP`:3001/health" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 Quick test commands:" -ForegroundColor Magenta
Write-Host "curl http://$ServerIP`:3001/health" -ForegroundColor White
Write-Host "curl http://$ServerIP`:3001/debug/env" -ForegroundColor White
