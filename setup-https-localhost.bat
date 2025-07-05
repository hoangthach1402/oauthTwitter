@echo off
echo 🚀 Complete HTTPS Localhost Setup
echo ====================================

echo.
echo 📋 Step 1: Creating SSL certificates...
call scripts\create-ssl-cert.bat

echo.
echo 📋 Step 2: Installing certificate to Windows Trust Store...
echo 💡 Installing certificate automatically...

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% equ 0 (
    echo ✅ Running with Administrator privileges
    powershell -Command "Import-Certificate -FilePath '%cd%\certs\localhost.crt' -CertStoreLocation Cert:\LocalMachine\Root" >nul 2>&1
    if %errorLevel% equ 0 (
        echo ✅ Certificate installed to Trusted Root store!
    ) else (
        echo ⚠️ Auto-install failed, manual installation required
    )
) else (
    echo ⚠️ Not running as Administrator
    echo 💡 Manual steps required:
    echo    1. Double-click certs\localhost.crt
    echo    2. Click "Install Certificate"
    echo    3. Store Location: "Local Machine" 
    echo    4. Certificate Store: "Trusted Root Certification Authorities"
    echo    5. Click "Yes" to security warning
)

echo.
echo 📋 Step 3: Building Docker image...
docker build -t oauth-twitter-backend .

echo.
echo 📋 Step 4: Running Docker container...
docker stop oauth-twitter-backend 2>nul
docker rm oauth-twitter-backend 2>nul
docker run -d --name oauth-twitter-backend -p 3001:3001 -p 3443:3443 -v %cd%\certs:/app/certs oauth-twitter-backend

echo.
echo 📋 Step 5: Testing endpoints...
timeout /t 5 /nobreak >nul
echo Testing HTTP...
curl -s http://localhost:3001/health
echo.
echo Testing HTTPS...
curl -k -s https://localhost:3443/health

echo.
echo ✅ Setup Complete!
echo.
echo 📍 Available URLs:
echo    HTTP:  http://localhost:3001/api/twitter/exchange-and-connect
echo    HTTPS: https://localhost:3443/api/twitter/exchange-and-connect
echo.
echo 💡 For frontend, use: https://localhost:3443
echo.
echo 🔗 Update Twitter App callback URL to:
echo    https://localhost:3443/auth/twitter/callback (for local testing)
echo.

pause
