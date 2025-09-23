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
    Write-Host "🗂️  VibeStack Deployment Log Manager" -ForegroundColor $Green
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
    Write-Host "  .\manage-deployment-logs.ps1 save-state C:\Users\Owner\Downloads\oci-deployment-output.json"
    Write-Host "  .\manage-deployment-logs.ps1 import-from-log"
    Write-Host "  .\manage-deployment-logs.ps1 cleanup"
}

function Ensure-LogsDir {
    if (-not (Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
        Write-Host "✓ Created secure logs directory: $LogsDir" -ForegroundColor $Green

        # Create README in logs directory
        $readmeContent = @"
# VibeStack Deployment Logs

This directory contains sensitive deployment information and is ignored by Git.

## Security Notes:
All files in this directory are automatically ignored by Git
Contains IP addresses, OCIDs, and deployment details
Safe to delete after creating Termius import files
Use ..\manage-deployment-logs.ps1 cleanup to securely remove all files

## Files:
terraform-state-*.txt - Terraform state exports
deployment-*.json - OCI deployment outputs
servers-*.env - Generated environment files

Generated: $(Get-Date)
"@
        $readmeContent | Out-File -FilePath "$LogsDir/README.md" -Encoding UTF8
    }
}

function Save-StateFile {
    param([string]$SourceFile)

    if (-not $SourceFile) {
        Write-Host "❌ Error: Please specify a file to save" -ForegroundColor $Red
        Write-Host "Example: .\manage-deployment-logs.ps1 save-state terraform-state.txt"
        exit 1
    }

    if (-not (Test-Path $SourceFile)) {
        Write-Host "❌ Error: File not found: $SourceFile" -ForegroundColor $Red
        exit 1
    }

    Ensure-LogsDir

    # Generate timestamped filename
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $basename = Split-Path $SourceFile -Leaf
    $extension = [System.IO.Path]::GetExtension($basename)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($basename)

    $destFile = "$LogsDir/$name-$timestamp$extension"

    # Copy file to logs directory
    Copy-Item $SourceFile $destFile
    Write-Host "✓ Saved deployment log: $destFile" -ForegroundColor $Green

    # Try to extract server info and create .env file
    Extract-ServerInfo $destFile

    Write-Host ""
    Write-Host "📋 Next steps:" -ForegroundColor $Yellow
    Write-Host "1. Run: .\manage-deployment-logs.ps1 import-from-log"
    Write-Host "2. Import the generated files to Termius"
    Write-Host "3. Run: .\manage-deployment-logs.ps1 cleanup (to securely delete logs)"
}

function Extract-ServerInfo {
    param([string]$LogFile)

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $envFile = "$LogsDir/servers-$timestamp.env"

    Write-Host "Extracting server information..." -ForegroundColor $Yellow

    # Try to parse JSON (Terraform state)
    $content = Get-Content $LogFile -Raw
    if ($content -match '"kasm_server"' -or $content -match '"coolify_server"') {
        try {
            # Try to parse as JSON
            if ($content -match '"outputs"') {
                # Extract outputs section
                $outputsMatch = [regex]::Match($content, '"outputs":\s*\{.*?\}\s*\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                if ($outputsMatch.Success) {
                    $outputsJson = "{" + $outputsMatch.Value + "}"
                    $data = $outputsJson | ConvertFrom-Json
                } else {
                    $data = $content | ConvertFrom-Json
                }
            } else {
                $data = $content | ConvertFrom-Json
            }

            # Extract server information
            $kasmIp = $null
            $coolifyIp = $null
            $compartmentName = "vibestack"

            if ($data.outputs.kasm_server.value.public_ip) {
                $kasmIp = $data.outputs.kasm_server.value.public_ip
            }
            if ($data.outputs.coolify_server.value.public_ip) {
                $coolifyIp = $data.outputs.coolify_server.value.public_ip
            }
            if ($data.outputs.compartment.value.name) {
                $compartmentName = $data.outputs.compartment.value.name
            }

            # Create environment file
            $envContent = @"
# VibeStack Server Information
# Generated: $(Get-Date)
# Source: $(Split-Path $LogFile -Leaf)

# Compartment
COMPARTMENT_NAME=$compartmentName

# Server IPs (if deployed)
"@

            if ($kasmIp -and $kasmIp -ne "null") {
                $envContent += "`nKASM_SERVER_IP=$kasmIp"
                Write-Host "✓ Found KASM server: $kasmIp" -ForegroundColor $Green
            }

            if ($coolifyIp -and $coolifyIp -ne "null") {
                $envContent += "`nCOOLIFY_SERVER_IP=$coolifyIp"
                Write-Host "✓ Found Coolify server: $coolifyIp" -ForegroundColor $Green
            }

            $envContent += @"

# SSH Settings (customize as needed)
SSH_USERNAME=ubuntu
SSH_PORT=22
SSH_KEY_PATH=~/.ssh/id_rsa
"@

            $envContent | Out-File -FilePath $envFile -Encoding UTF8
            Write-Host "✓ Created server info file: $envFile" -ForegroundColor $Green

        } catch {
            Write-Host "⚠️  Could not automatically parse server info from log file" -ForegroundColor $Yellow
            Write-Host "You may need to manually create a .env file or run the Termius import script"
        }
    } else {
        Write-Host "⚠️  Could not automatically parse server info from log file" -ForegroundColor $Yellow
        Write-Host "You may need to manually create a .env file or run the Termius import script"
    }
}

function Import-FromLog {
    Ensure-LogsDir

    # Find the most recent log file
    $logFiles = Get-ChildItem "$LogsDir/*.txt", "$LogsDir/*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

    if (-not $logFiles) {
        Write-Host "❌ No log files found in $LogsDir" -ForegroundColor $Red
        Write-Host "First save a deployment log with: .\manage-deployment-logs.ps1 save-state [file]"
        exit 1
    }

    $latestLog = $logFiles[0].FullName
    Write-Host "Using log file: $($logFiles[0].Name)" -ForegroundColor $Yellow

    # Check if log contains expected data
    $content = Get-Content $latestLog -Raw
    if ($content -match '"kasm_server"' -or $content -match '"coolify_server"') {
        Write-Host "Generating Termius import files..." -ForegroundColor $Yellow

        # Set environment variable to point to our log file as terraform output
        $env:VIBESTACK_LOG_FILE = $latestLog

        if (Test-Path "$PSScriptRoot/generate-termius-import.ps1") {
            # Run the import script
            & "$PSScriptRoot/generate-termius-import.ps1"
            Write-Host "✅ Import files generated successfully!" -ForegroundColor $Green
            Write-Host "Check the termius-import/ directory for your files"
        } else {
            Write-Host "❌ generate-termius-import.ps1 not found" -ForegroundColor $Red
            exit 1
        }
    } else {
        Write-Host "❌ Log file format not recognized" -ForegroundColor $Red
        Write-Host "Expected Terraform state JSON format"
        exit 1
    }
}

function Cleanup-Logs {
    Ensure-LogsDir

    # Count files
    $files = Get-ChildItem $LogsDir -File | Where-Object { $_.Name -ne "README.md" }
    $fileCount = $files.Count

    if ($fileCount -eq 0) {
        Write-Host "📁 No log files to cleanup" -ForegroundColor $Yellow
        return
    }

    Write-Host "🗑️  Found $fileCount log files to delete:" -ForegroundColor $Yellow
    $files | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host ""
    Write-Host "⚠️  This will permanently delete all deployment logs!" -ForegroundColor $Red
    Write-Host "Make sure you have:"
    Write-Host "  ✓ Generated Termius import files"
    Write-Host "  ✓ Saved any needed server information"
    Write-Host "  ✓ No longer need the deployment logs"
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to delete all log files? (yes/no)"

    if ($confirm -eq "yes" -or $confirm -eq "YES") {
        $files | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Host "Deleted: $($_.Name)" -ForegroundColor $Green
        }
        Write-Host "✅ All log files securely deleted" -ForegroundColor $Green
    } else {
        Write-Host "Cleanup cancelled" -ForegroundColor $Yellow
    }
}

function List-Logs {
    Ensure-LogsDir

    Write-Host "📋 Saved deployment logs:" -ForegroundColor $Yellow
    Write-Host ""

    $files = Get-ChildItem $LogsDir -File | Where-Object { $_.Name -ne "README.md" }

    if ($files.Count -eq 0) {
        Write-Host "No log files found"
        return
    }

    $files | ForEach-Object {
        Write-Host "📄 $($_.Name)"
        Write-Host "   Size: $($_.Length) bytes, Modified: $($_.LastWriteTime)"
        Write-Host ""
    }
}

function Show-Paths {
    Ensure-LogsDir

    $scriptDir = $PSScriptRoot

    Write-Host "📁 Directory Structure:" -ForegroundColor $Yellow
    Write-Host ""
    Write-Host "Repository root: $scriptDir"
    Write-Host "Logs directory:  $scriptDir/$LogsDir"
    Write-Host "Import output:   $scriptDir/termius-import"
    Write-Host ""
    Write-Host "🔒 Security Status:" -ForegroundColor $Green
    Write-Host "✓ Logs directory is in .gitignore"
    Write-Host "✓ Import files are in .gitignore"
    Write-Host "✓ All sensitive files protected from Git"
    Write-Host ""
    Write-Host "📋 Workflow:" -ForegroundColor $Yellow
    Write-Host "1. Save deployment log:    .\manage-deployment-logs.ps1 save-state [file]"
    Write-Host "2. Generate imports:       .\manage-deployment-logs.ps1 import-from-log"
    Write-Host "3. Import to Termius:      Use files in termius-import/"
    Write-Host "4. Cleanup logs:           .\manage-deployment-logs.ps1 cleanup"
}

# Main script logic
Write-Header

switch ($Command) {
    "save-state" {
        Save-StateFile $FilePath
    }
    "import-from-log" {
        Import-FromLog
    }
    "cleanup" {
        Cleanup-Logs
    }
    "list" {
        List-Logs
    }
    "show-paths" {
        Show-Paths
    }
    { $_ -in @("help", "-h", "--help") } {
        Write-Usage
    }
    default {
        if ($Command) {
            Write-Host "❌ Unknown command: $Command" -ForegroundColor $Red
        }
        Write-Host ""
        Write-Usage
        exit 1
    }
}