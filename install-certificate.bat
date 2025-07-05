@echo off
echo 🔒 Installing SSL certificate to Windows Trust Store...

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ This script requires Administrator privileges
    echo    Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo 📜 Installing certificate to Trusted Root Certification Authorities...
certlm.msc /s

REM Alternative method using PowerShell
powershell -Command "Import-Certificate -FilePath '%cd%\certs\localhost.crt' -CertStoreLocation Cert:\LocalMachine\Root"

if %errorLevel% equ 0 (
    echo ✅ Certificate installed successfully!
    echo 🌐 You can now access https://localhost:3443 without security warnings
) else (
    echo ❌ Failed to install certificate
    echo 💡 Please install manually by double-clicking certs\localhost.crt
)

echo.
echo 🧪 Testing HTTPS endpoint...
curl -s https://localhost:3443/health

pause
