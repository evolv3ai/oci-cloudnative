# PowerShell script to apply the Cloudflare SSL fix
# Run this from D:\oci-cloudnative directory

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Cloudflare Origin Certificate Fix" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check we're in the right directory
if (-not (Test-Path ".\deploy\coolify\cloud-init-coolify.yaml")) {
    Write-Host "ERROR: Not in oci-cloudnative directory!" -ForegroundColor Red
    Write-Host "Please cd to D:\oci-cloudnative first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Current directory: $(Get-Location)" -ForegroundColor Green
Write-Host ""

# Backup current file
Write-Host "Step 1: Backing up current cloud-init file..." -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = ".\deploy\coolify\cloud-init-coolify.yaml.backup-$timestamp"
Copy-Item ".\deploy\coolify\cloud-init-coolify.yaml" $backupFile
Write-Host "✓ Backed up to: $backupFile" -ForegroundColor Green
Write-Host ""

# Apply the fix
Write-Host "Step 2: Applying the fix..." -ForegroundColor Yellow
if (Test-Path ".\fixes\cloud-init-coolify-CLOUDFLARE-FIXED.yaml") {
    Copy-Item ".\fixes\cloud-init-coolify-CLOUDFLARE-FIXED.yaml" ".\deploy\coolify\cloud-init-coolify.yaml" -Force
    Write-Host "✓ Fixed cloud-init file applied" -ForegroundColor Green
} else {
    Write-Host "ERROR: Fixed file not found at .\fixes\cloud-init-coolify-CLOUDFLARE-FIXED.yaml" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Show what changed
Write-Host "Step 3: Key changes made:" -ForegroundColor Yellow
Write-Host "- Removed double base64 encoding" -ForegroundColor Cyan
Write-Host "- Removed certificate format 'fixing' that was breaking them" -ForegroundColor Cyan
Write-Host "- Added better validation and logging" -ForegroundColor Cyan
Write-Host "- Fixed file paths for ssl.cert and ssl.key" -ForegroundColor Cyan
Write-Host ""

# Git status
Write-Host "Step 4: Git status..." -ForegroundColor Yellow
git status --short ".\deploy\coolify\cloud-init-coolify.yaml"
Write-Host ""

# Next steps
Write-Host "=====================================" -ForegroundColor Green
Write-Host "FIX APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the changes:" -ForegroundColor White
Write-Host "   git diff deploy/coolify/cloud-init-coolify.yaml" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Commit the fix:" -ForegroundColor White
Write-Host "   git add deploy/coolify/cloud-init-coolify.yaml" -ForegroundColor Gray
Write-Host "   git commit -m 'Fix: SSL certificate processing for Cloudflare Origin certs'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Push to GitHub:" -ForegroundColor White
Write-Host "   git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Create a new release on GitHub" -ForegroundColor White
Write-Host ""
Write-Host "5. Update your OCI Stack to use the new release" -ForegroundColor White
Write-Host ""
Write-Host "6. Deploy and test with your Cloudflare Origin certificates" -ForegroundColor White
Write-Host ""

# Offer to show diff
$response = Read-Host "Would you like to see the changes now? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host ""
    Write-Host "Showing key changes (SSL processing section):" -ForegroundColor Yellow
    Write-Host "===============================================" -ForegroundColor Gray
    git diff --unified=3 ".\deploy\coolify\cloud-init-coolify.yaml" | Select-String -Pattern "SSL|ssl|cert|key" -Context 2
}

Write-Host ""
Write-Host "Done! Your Cloudflare Origin certificates should work correctly now." -ForegroundColor Green
