# Connect to Microsoft Graph (make sure you have the right permissions)
Connect-MgGraph -Scopes "Application.Read.All", "Directory.Read.All"

# Get all Enterprise Apps with the specified tag
$apps = Get-MgServicePrincipal -All -Filter "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')"

# Create an array to store results
$results = @()

foreach ($app in $apps) {
    Write-Host "Processing app: $($app.DisplayName)"
    
    # Get app owners
    $owners = Get-MgServicePrincipalOwner -ServicePrincipalId $app.Id
    $ownerNames = if ($owners) {
        ($owners | ForEach-Object { $_.AdditionalProperties.userPrincipalName }) -join '; '
    } else {
        "No Owner"
    }
    
    # Get app assignments
    $assignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $app.Id
    $assignedUsers = @()
    $assignedGroups = @()
    
    foreach ($assignment in $assignments) {
        if ($assignment.PrincipalType -eq "User") {
            $user = Get-MgUser -UserId $assignment.PrincipalId
            $assignedUsers += $user.UserPrincipalName
        }
        elseif ($assignment.PrincipalType -eq "Group") {
            $group = Get-MgGroup -GroupId $assignment.PrincipalId
            $assignedGroups += $group.DisplayName
        }
    }
    
    # Create result object
    $resultObj = [PSCustomObject]@{
        AppDisplayName = $app.DisplayName
        AppId = $app.AppId
        ObjectId = $app.Id
        Owners = $ownerNames
        AssignedUsers = ($assignedUsers -join '; ')
        AssignedGroups = ($assignedGroups -join '; ')
    }
    
    $results += $resultObj
}

# Export to CSV
$results | Export-Csv -Path "EnterpriseApps_Inventory.csv" -NoTypeInformation

Write-Host "Export completed. File saved as EnterpriseApps_Inventory.csv"
