# VibeStack Termius Import Generator (PowerShell)
# Generates import files for Termius SSH client from Terraform outputs

param(
    [string]$TerraformDir = "./terraform/vibestack",
    [string]$OutputDir = "./termius-import"
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"

Write-Host "🚀 VibeStack Termius Import Generator" -ForegroundColor $Green
Write-Host "======================================" -ForegroundColor $Green

# Load environment variables from .env file if it exists
if (Test-Path ".env") {
    Write-Host "Loading configuration from .env file..." -ForegroundColor $Yellow
    Get-Content ".env" | Where-Object { $_ -notmatch '^#' -and $_ -match '=' } | ForEach-Object {
        $name, $value = $_ -split '=', 2
        Set-Variable -Name $name.Trim() -Value $value.Trim() -Scope Global
    }
}

# Set defaults
if (-not $SSH_USERNAME) { $SSH_USERNAME = "ubuntu" }
if (-not $SSH_PORT) { $SSH_PORT = "22" }
if (-not $SSH_KEY_PATH) { $SSH_KEY_PATH = "~/.ssh/id_rsa" }

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Function to get Terraform output
function Get-TerraformOutput {
    # Check if we're using a log file instead of live terraform
    if ($env:VIBESTACK_LOG_FILE -and (Test-Path $env:VIBESTACK_LOG_FILE)) {
        Write-Host "Using log file: $(Split-Path $env:VIBESTACK_LOG_FILE -Leaf)" -ForegroundColor $Yellow

        $content = Get-Content $env:VIBESTACK_LOG_FILE -Raw

        # Extract outputs from log file
        if ($content -match '"outputs"') {
            # Full terraform state - parse as JSON and extract outputs
            try {
                $fullState = $content | ConvertFrom-Json
                if ($fullState.outputs) {
                    return ($fullState.outputs | ConvertTo-Json -Depth 10)
                }
            } catch {
                Write-Host "Warning: Could not parse full state as JSON, trying regex extraction..." -ForegroundColor $Yellow
                # Fallback to regex extraction
                $outputsStart = $content.IndexOf('"outputs":')
                if ($outputsStart -ge 0) {
                    $outputsSection = $content.Substring($outputsStart)
                    # Find the matching closing brace for outputs
                    $braceCount = 0
                    $inString = $false
                    $escapeNext = $false
                    $outputsEnd = -1

                    for ($i = 0; $i -lt $outputsSection.Length; $i++) {
                        $char = $outputsSection[$i]

                        if ($escapeNext) {
                            $escapeNext = $false
                            continue
                        }

                        if ($char -eq '\') {
                            $escapeNext = $true
                            continue
                        }

                        if ($char -eq '"') {
                            $inString = -not $inString
                            continue
                        }

                        if (-not $inString) {
                            if ($char -eq '{') {
                                $braceCount++
                            } elseif ($char -eq '}') {
                                $braceCount--
                                if ($braceCount -eq 0) {
                                    $outputsEnd = $i + 1
                                    break
                                }
                            }
                        }
                    }

                    if ($outputsEnd -gt 0) {
                        $extractedOutputs = $outputsSection.Substring(0, $outputsEnd)
                        return "{$extractedOutputs}"
                    }
                }
            }
        }
        # Assume it's already the outputs section
        return $content
    } else {
        # Standard terraform output
        Push-Location $TerraformDir
        try {
            $output = terraform output -json 2>$null
            if ($LASTEXITCODE -ne 0) {
                return "{}"
            }
            return $output
        }
        finally {
            Pop-Location
        }
    }
}

Write-Host "Fetching Terraform outputs..." -ForegroundColor $Yellow
$TfOutput = Get-TerraformOutput

# Check if terraform output is valid
if ($TfOutput -eq "{}") {
    Write-Host "❌ Error: No Terraform outputs found!" -ForegroundColor $Red
    Write-Host "Please ensure you have run 'terraform apply' in $TerraformDir" -ForegroundColor $Red
    exit 1
}

# Parse JSON output
$tfData = $TfOutput | ConvertFrom-Json

# Extract server information
$kasmServer = $tfData.kasm_server.value
$coolifyServer = $tfData.coolify_server.value
$compartment = $tfData.compartment.value

$kasmIp = if ($kasmServer) { $kasmServer.public_ip } else { $null }
$coolifyIp = if ($coolifyServer) { $coolifyServer.public_ip } else { $null }
$kasmPrivateIp = if ($kasmServer) { $kasmServer.private_ip } else { $null }
$coolifyPrivateIp = if ($coolifyServer) { $coolifyServer.private_ip } else { $null }
$compartmentName = if ($compartment) { $compartment.name } else { "vibestack" }

# Check which servers are deployed
$serversDeployed = @()
if ($kasmIp) {
    $serversDeployed += "kasm"
    Write-Host "✓ KASM Server found: $kasmIp" -ForegroundColor $Green
}
if ($coolifyIp) {
    $serversDeployed += "coolify"
    Write-Host "✓ Coolify Server found: $coolifyIp" -ForegroundColor $Green
}

if ($serversDeployed.Count -eq 0) {
    Write-Host "❌ No servers found in Terraform output!" -ForegroundColor $Red
    exit 1
}

# Generate CSV file
Write-Host "Generating CSV import file..." -ForegroundColor $Yellow
$csvContent = @("Groups,Label,Tags,Hostname/IP,Protocol,Port")

if ($kasmIp) {
    $csvContent += "VibeStack OCI - $compartmentName,KASM-server-$compartmentName,""vibestack,kasm,oci"",$kasmIp,ssh,$SSH_PORT"
}

if ($coolifyIp) {
    $csvContent += "VibeStack OCI - $compartmentName,Coolify-server-$compartmentName,""vibestack,coolify,oci"",$coolifyIp,ssh,$SSH_PORT"
}

$csvContent | Out-File -FilePath "$OutputDir/vibestack-termius.csv" -Encoding UTF8

# Generate SSH config file
Write-Host "Generating SSH config file..." -ForegroundColor $Yellow
$sshConfig = @(
    "# VibeStack OCI Servers SSH Configuration",
    "# Generated: $(Get-Date)",
    "# Compartment: $compartmentName",
    "# Add this to your ~/.ssh/config file or import via ssh_config format in Termius",
    ""
)

if ($kasmIp) {
    $sshConfig += @(
        "Host $compartmentName-kasm",
        "    HostName $kasmIp",
        "    User $SSH_USERNAME",
        "    Port $SSH_PORT",
        "    IdentityFile $SSH_KEY_PATH",
        "    StrictHostKeyChecking no",
        "    UserKnownHostsFile /dev/null",
        "    # KASM Workspaces server (2 OCPUs, 12GB RAM, 60GB storage)",
        "    # Private IP: $kasmPrivateIp",
        ""
    )
}

if ($coolifyIp) {
    $sshConfig += @(
        "Host $compartmentName-coolify",
        "    HostName $coolifyIp",
        "    User $SSH_USERNAME",
        "    Port $SSH_PORT",
        "    IdentityFile $SSH_KEY_PATH",
        "    StrictHostKeyChecking no",
        "    UserKnownHostsFile /dev/null",
        "    # Coolify app platform server (2 OCPUs, 12GB RAM, 100GB storage)",
        "    # Private IP: $coolifyPrivateIp",
        ""
    )
}

$sshConfig | Out-File -FilePath "$OutputDir/vibestack-ssh-config" -Encoding UTF8

# Generate JSON file
Write-Host "Generating JSON import file..." -ForegroundColor $Yellow
$hosts = @()

if ($kasmIp) {
    $hosts += @{
        label = "KASM-server-$compartmentName"
        address = $kasmIp
        username = $SSH_USERNAME
        port = [int]$SSH_PORT
        tags = @("vibestack", "oci", "kasm", $compartmentName)
        notes = "KASM Workspaces server - VibeStack deployment`n2 OCPUs, 12GB RAM, 60GB storage`nPrivate IP: $kasmPrivateIp"
        group = "VibeStack OCI - $compartmentName"
    }
}

if ($coolifyIp) {
    $hosts += @{
        label = "Coolify-server-$compartmentName"
        address = $coolifyIp
        username = $SSH_USERNAME
        port = [int]$SSH_PORT
        tags = @("vibestack", "oci", "coolify", $compartmentName)
        notes = "Coolify app platform server - VibeStack deployment`n2 OCPUs, 12GB RAM, 100GB storage`nPrivate IP: $coolifyPrivateIp"
        group = "VibeStack OCI - $compartmentName"
    }
}

$jsonData = @{ hosts = $hosts }
$jsonData | ConvertTo-Json -Depth 10 | Out-File -FilePath "$OutputDir/vibestack-termius.json" -Encoding UTF8

# Generate quick connect PowerShell script
Write-Host "Generating quick connect script..." -ForegroundColor $Yellow
$connectScript = @(
    "# Quick connect script for VibeStack servers",
    "",
    "Write-Host 'VibeStack Server Connection'",
    "Write-Host '=========================='",
    "Write-Host '1) KASM Server'",
    "Write-Host '2) Coolify Server'",
    '$choice = Read-Host "Select server [1-2]"',
    "",
    "switch ($choice) {"
)

if ($kasmIp) {
    $connectScript += @(
        "    1 {",
        "        Write-Host 'Connecting to KASM server ($kasmIp)...'",
        "        ssh -i `"$SSH_KEY_PATH`" -p $SSH_PORT $SSH_USERNAME@$kasmIp",
        "    }"
    )
}

if ($coolifyIp) {
    $connectScript += @(
        "    2 {",
        "        Write-Host 'Connecting to Coolify server ($coolifyIp)...'",
        "        ssh -i `"$SSH_KEY_PATH`" -p $SSH_PORT $SSH_USERNAME@$coolifyIp",
        "    }"
    )
}

$connectScript += @(
    "    default {",
    "        Write-Host 'Invalid selection'",
    "        exit 1",
    "    }",
    "}"
)

$connectScript | Out-File -FilePath "$OutputDir/connect.ps1" -Encoding UTF8

# Summary
Write-Host ""
Write-Host "✅ Import files generated successfully!" -ForegroundColor $Green
Write-Host "======================================" -ForegroundColor $Green
Write-Host "Files created in: $OutputDir" -ForegroundColor $Yellow
Write-Host ""
Write-Host "📁 Generated files:"
Write-Host "  • vibestack-termius.csv    - CSV format for Termius import"
Write-Host "  • vibestack-termius.json   - JSON format for Termius import"
Write-Host "  • vibestack-ssh-config     - SSH config format"
Write-Host "  • connect.ps1              - Quick connect script (PowerShell)"
Write-Host ""
Write-Host "🚀 To import in Termius:"
Write-Host "  1. Open Termius"
Write-Host "  2. Go to Settings > Import"
Write-Host "  3. Select CSV and choose: $OutputDir/vibestack-termius.csv"
Write-Host ""
Write-Host "🔗 Quick access URLs:"
if ($kasmIp) {
    Write-Host "  • KASM:    https://$kasmIp"
}
if ($coolifyIp) {
    Write-Host "  • Coolify: http://$coolifyIp:3000"
}