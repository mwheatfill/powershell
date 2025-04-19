
# Retrieve all service principals (enterprise apps)
$apps = Get-MgServicePrincipal -All

# Optional: Get app role assignments (to check for assigned users/groups)
$appAssignments = @{}
foreach ($app in $apps) {
    $assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $app.Id -ErrorAction SilentlyContinue
    $appAssignments[$app.Id] = $assignments.Count
}

# Build a result list with useful properties
$results = $apps | Select-Object `
    DisplayName,
    Id,
    AppId,
    PublisherName,
    AppOwnerOrganizationId,
    @{Name="AppRoleAssignmentCount"; Expression={ $appAssignments[$_.Id] }},
    SignInAudience,
    @{Name="Tags"; Expression={ $_.Tags -join ", " }},
    @{Name="LikelySSO"; Expression={
        ($_.Tags -contains "WindowsAzureActiveDirectoryIntegratedApp") -or
        ($_.PublisherName -ne "Microsoft" -and $appAssignments[$_.Id] -gt 0)
    }}

# Export to CSV
$results | Export-Csv -Path ".\EnterpriseApps_Analysis.csv" -NoTypeInformation

Write-Host "Export complete: EnterpriseApps_Analysis.csv"