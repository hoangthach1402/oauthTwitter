@echo off
echo 🚀 Simple deployment to server...

echo 📤 Uploading files...
scp -r * root@207.180.251.81:/var/www/twitter-oauth-backend/

echo 🔧 Deploying on server...
ssh root@207.180.251.81 "cd /var/www/twitter-oauth-backend && cat > .env << 'EOF'
NODE_ENV=production
PORT=3001
TWITTER_CLIENT_ID=T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ
TWITTER_CLIENT_SECRET=9R8RECRDHOuFpZCT_7U4FwrPYI4WjAGllHmJq52
TWITTER_REDIRECT_URI=https://your-frontend-domain.com/auth/twitter/callback
FIRESTARTER_API_BASE_URL=https://api2.khanhdev.tech/api/v1/trustcore
EOF
&& docker stop twitter-oauth-backend 2>nul || echo Stopping old container
&& docker rm twitter-oauth-backend 2>nul || echo Removing old container  
&& docker build -t twitter-oauth-backend .
&& docker run -d --name twitter-oauth-backend --restart unless-stopped -p 3001:3001 --env-file .env twitter-oauth-backend
&& timeout /t 10 >nul
&& docker ps | findstr twitter-oauth-backend
&& echo ✅ Deployment done! API at: http://207.180.251.81:3001"

echo 🎉 Script completed!
pause
