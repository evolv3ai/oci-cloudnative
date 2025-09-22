# PowerShell script to check resources in devlab compartment
# Run this to see what needs to be deleted

$COMPARTMENT_ID = "ocid1.compartment.oc1..aaaaaaaae5v3sal4r6df2hrucviwerue5k3trdiln5buhh7wggjjgw2f7wua"
$REGION = "us-ashburn-1"  # Change this to your region if different

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Checking resources in devlab compartment" -ForegroundColor Cyan
Write-Host "Compartment ID: $COMPARTMENT_ID" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "CHECKING ALL RESOURCES IN COMPARTMENT:" -ForegroundColor Green
Write-Host "--------------------------------------" -ForegroundColor Green

# Search for all resources in the compartment
Write-Host "`nSearching for all resources..." -ForegroundColor Yellow
$searchCmd = "oci search resource structured-search --query-text `"query all resources where compartmentId = '$COMPARTMENT_ID'`" --region $REGION"
Write-Host "Running: $searchCmd" -ForegroundColor Gray
$result = Invoke-Expression $searchCmd | ConvertFrom-Json

if ($result.data.items.Count -eq 0) {
    Write-Host "`nNo resources found in compartment. It should be safe to delete." -ForegroundColor Green
} else {
    Write-Host "`nFound $($result.data.items.Count) resource(s):" -ForegroundColor Red

    $result.data.items | ForEach-Object {
        Write-Host ""
        Write-Host "Resource Type: $($_.'resource-type')" -ForegroundColor Yellow
        Write-Host "Display Name: $($_.'display-name')" -ForegroundColor White
        Write-Host "State: $($_.'lifecycle-state')" -ForegroundColor Cyan
        Write-Host "OCID: $($_.identifier)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

if ($result.data.items.Count -gt 0) {
    Write-Host "1. Delete the resources listed above" -ForegroundColor Yellow
    Write-Host "2. Run this script again to verify all resources are gone" -ForegroundColor Yellow
    Write-Host "3. Then delete the compartment with:" -ForegroundColor Yellow
    Write-Host "   oci iam compartment delete --compartment-id $COMPARTMENT_ID --force" -ForegroundColor White
} else {
    Write-Host "The compartment appears to be empty!" -ForegroundColor Green
    Write-Host "You can delete it with:" -ForegroundColor Green
    Write-Host "   oci iam compartment delete --compartment-id $COMPARTMENT_ID --force" -ForegroundColor White
}

Write-Host ""
Write-Host "For detailed cleanup commands, see: cleanup-devlab-commands.txt" -ForegroundColor Gray