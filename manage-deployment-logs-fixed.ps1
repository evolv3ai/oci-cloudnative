# VibeStack Deployment Log Manager (PowerShell)
# Manages sensitive Terraform state files and deployment logs securely

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$FilePath
)

$LogsDir = "./logs"
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"

function Write-Header {
    Write-Host "VibeStack Deployment Log Manager" -ForegroundColor $Green
    Write-Host "==========================================="
}

function Write-Usage {
    Write-Host "Usage: .\manage-deployment-logs.ps1 [COMMAND] [OPTIONS]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  save-state [file]     - Save Terraform state/log file to secure logs directory"
    Write-Host "  import-from-log       - Generate Termius imports from saved log file"
    Write-Host "  cleanup              - Securely delete all log files after confirmation"
    Write-Host "  list                 - List all saved log files"
    Write-Host "  show-paths           - Show directory structure and safety"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\manage-deployment-logs.ps1 save-state terraform-state.txt"
    Write-Host "  .\manage-deployment-logs.ps1 import-from-log"
    Write-Host "  .\manage-deployment-logs.ps1 cleanup"
}

function Import-FromLog {
    if (-not (Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }

    # Find the most recent log file
    $logFiles = Get-ChildItem "$LogsDir/*.txt", "$LogsDir/*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

    if (-not $logFiles) {
        Write-Host "No log files found in $LogsDir" -ForegroundColor $Red
        Write-Host "First save a deployment log with: .\manage-deployment-logs.ps1 save-state [file]"
        return
    }

    $latestLog = $logFiles[0].FullName
    Write-Host "Using log file: $($logFiles[0].Name)" -ForegroundColor $Yellow

    # Set environment variable to point to our log file
    $env:VIBESTACK_LOG_FILE = $latestLog

    if (Test-Path "./generate-termius-import.ps1") {
        Write-Host "Generating Termius import files..." -ForegroundColor $Yellow
        & "./generate-termius-import.ps1"
        Write-Host "Import files generated successfully!" -ForegroundColor $Green
        Write-Host "Check the termius-import/ directory for your files"
    } else {
        Write-Host "generate-termius-import.ps1 not found" -ForegroundColor $Red
    }
}

# Main script logic
Write-Header

switch ($Command) {
    "import-from-log" {
        Import-FromLog
    }
    default {
        Write-Host "For this quick test, only import-from-log is implemented" -ForegroundColor $Yellow
        Write-Host "Use: .\manage-deployment-logs.ps1 import-from-log"
    }
}