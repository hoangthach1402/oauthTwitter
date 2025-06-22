# Docker Manager PowerShell Script for Twitter OAuth Backend
# Usage: .\docker-manager.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Port = "3001"
)

$ProjectName = "twitter-oauth-backend"
$ComposeFile = "docker-compose.yml"

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Show-Usage {
    Write-Host "Docker Manager for Twitter OAuth Backend" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Usage: .\docker-manager.ps1 [COMMAND]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  build        Build Docker image" -ForegroundColor White
    Write-Host "  start        Start containers" -ForegroundColor White
    Write-Host "  stop         Stop containers" -ForegroundColor White
    Write-Host "  restart      Restart containers" -ForegroundColor White
    Write-Host "  logs         Show logs" -ForegroundColor White
    Write-Host "  status       Show container status" -ForegroundColor White
    Write-Host "  shell        Access container shell" -ForegroundColor White
    Write-Host "  clean        Clean up containers and images" -ForegroundColor White
    Write-Host "  health       Check application health" -ForegroundColor White
    Write-Host "  env          Show environment variables" -ForegroundColor White
    Write-Host "  deploy       Full deploy (build + start)" -ForegroundColor White
    Write-Host "  backup       Backup logs and config" -ForegroundColor White
    Write-Host "  update       Pull latest changes and redeploy" -ForegroundColor White
    Write-Host "  port         Check and manage port usage" -ForegroundColor White
    Write-Host ""
}

function Test-EnvFile {
    if (-not (Test-Path ".env")) {
        Write-ColoredOutput "Error: .env file not found!" "Red"
        Write-ColoredOutput "Please copy .env.example to .env and configure it:" "Yellow"
        Write-ColoredOutput "Copy-Item .env.example .env" "Blue"
        exit 1
    }
}

function Build-Image {
    Write-ColoredOutput "Building Docker image..." "Blue"
    docker-compose build --no-cache
    if ($LASTEXITCODE -eq 0) {
        Write-ColoredOutput "Build completed!" "Green"
    } else {
        Write-ColoredOutput "Build failed!" "Red"
        exit 1
    }
}

function Start-Containers {
    Test-EnvFile
    Write-ColoredOutput "Starting containers..." "Blue"
    docker-compose up -d
    if ($LASTEXITCODE -eq 0) {
        Write-ColoredOutput "Containers started!" "Green"
        Start-Sleep -Seconds 5
        Show-Status
    } else {
        Write-ColoredOutput "Failed to start containers!" "Red"
        exit 1
    }
}

function Stop-Containers {
    Write-ColoredOutput "Stopping containers..." "Blue"
    docker-compose down
    if ($LASTEXITCODE -eq 0) {
        Write-ColoredOutput "Containers stopped!" "Green"
    } else {
        Write-ColoredOutput "Failed to stop containers!" "Red"
    }
}

function Restart-Containers {
    Write-ColoredOutput "Restarting containers..." "Blue"
    Stop-Containers
    Start-Containers
}

function Show-Logs {
    docker-compose logs -f --tail=100
}

function Show-Status {
    Write-ColoredOutput "Container Status:" "Blue"
    docker-compose ps
    Write-Host ""
    Write-ColoredOutput "Resource Usage:" "Blue"
    $stats = docker stats --no-stream $ProjectName 2>$null
    if ($stats) {
        $stats
    } else {
        Write-ColoredOutput "Container not running or stats unavailable" "Yellow"
    }
}

function Enter-Shell {
    Write-ColoredOutput "Accessing container shell..." "Blue"
    docker exec -it $ProjectName sh
}

function Clean-Up {
    $response = Read-Host "This will remove all containers and images. Continue? (y/N)"
    if ($response -match "^[yY]") {
        Write-ColoredOutput "Cleaning up..." "Blue"
        docker-compose down --volumes --remove-orphans
        docker image prune -f
        docker container prune -f
        Write-ColoredOutput "Cleanup completed!" "Green"
    } else {
        Write-ColoredOutput "Cleanup cancelled." "Yellow"
    }
}

function Test-Health {
    Write-ColoredOutput "Checking application health..." "Blue"
    
    # Check if container is running
    $containerStatus = docker-compose ps | Select-String "Up"
    if (-not $containerStatus) {
        Write-ColoredOutput "Container is not running!" "Red"
        return $false
    }
    
    # Check health endpoint
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3001/health" -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-ColoredOutput "✓ Application is healthy!" "Green"
            Write-Host ""
            Write-ColoredOutput "Health Check Response:" "Blue"
            Write-Host $response.Content
            return $true
        }
    } catch {
        Write-ColoredOutput "✗ Application health check failed!" "Red"
        Write-ColoredOutput "Checking logs..." "Yellow"
        docker-compose logs --tail=20 $ProjectName
        return $false
    }
}

function Show-Environment {
    Write-ColoredOutput "Environment Variables:" "Blue"
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3001/debug/env" -TimeoutSec 10
        Write-Host $response.Content
    } catch {
        Write-ColoredOutput "Cannot access debug endpoint" "Red"
    }
}

function Deploy-Full {
    Write-ColoredOutput "Starting full deployment..." "Blue"
    Test-EnvFile
    Build-Image
    Start-Containers
    if (Test-Health) {
        Write-ColoredOutput "Deployment completed successfully!" "Green"
    } else {
        Write-ColoredOutput "Deployment completed but health check failed!" "Yellow"
    }
}

function Backup-Data {
    $BackupDir = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-ColoredOutput "Creating backup in $BackupDir..." "Blue"
    
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    
    # Backup .env example
    Copy-Item ".env.example" "$BackupDir/"
    
    # Backup logs
    docker-compose logs > "$BackupDir/container_logs.txt" 2>$null
    
    # Backup docker configs
    Copy-Item "docker-compose.yml" "$BackupDir/"
    Copy-Item "Dockerfile" "$BackupDir/"
    
    Write-ColoredOutput "Backup created in $BackupDir" "Green"
}

function Update-Deploy {
    Write-ColoredOutput "Updating and redeploying..." "Blue"
    
    # Pull latest changes if in git repo
    if (Test-Path ".git") {
        Write-ColoredOutput "Pulling latest changes..." "Blue"
        git pull
    }
    
    # Rebuild and restart
    Deploy-Full
}

function Test-Port {
    param([string]$PortNumber = "3001")
    
    Write-ColoredOutput "Checking port $PortNumber..." "Blue"
    
    $process = Get-NetTCPConnection -LocalPort $PortNumber -ErrorAction SilentlyContinue
    if ($process) {
        Write-ColoredOutput "Port $PortNumber is in use:" "Yellow"
        $processInfo = Get-Process -Id $process.OwningProcess -ErrorAction SilentlyContinue
        if ($processInfo) {
            Write-Host "Process: $($processInfo.ProcessName) (PID: $($processInfo.Id))"
            $response = Read-Host "Kill process? (y/N)"
            if ($response -match "^[yY]") {
                Stop-Process -Id $processInfo.Id -Force
                Write-ColoredOutput "Process killed!" "Green"
            }
        }
    } else {
        Write-ColoredOutput "Port $PortNumber is available!" "Green"
    }
}

# Main command handler
switch ($Command.ToLower()) {
    "build" { Build-Image }
    "start" { Start-Containers }
    "stop" { Stop-Containers }
    "restart" { Restart-Containers }
    "logs" { Show-Logs }
    "status" { Show-Status }
    "shell" { Enter-Shell }
    "clean" { Clean-Up }
    "health" { Test-Health }
    "env" { Show-Environment }
    "deploy" { Deploy-Full }
    "backup" { Backup-Data }
    "update" { Update-Deploy }
    "port" { Test-Port -PortNumber $Port }
    default { Show-Usage }
}
