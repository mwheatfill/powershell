# Connect to Microsoft Graph (make sure you have the right permissions)
Connect-MgGraph -Scopes "Application.Read.All", "Directory.Read.All"

# Get all Enterprise Apps with the specified tag
$apps = Get-MgServicePrincipal -All -Filter "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')"

# Create an array to store results
$results = @()

foreach ($app in $apps) {
    Write-Host "Processing app: $($app.DisplayName)"
    
    # Get app assignments first (we'll need this for owner fallback)
    $assignments = Get-MgServicePrincipalAppRoleAssignedTo -All -ServicePrincipalId $app.Id
    $assignedUsers = @()
    $assignedGroups = @()
    
    foreach ($assignment in $assignments) {
        if ($assignment.PrincipalType -eq "User") {
            $user = Get-MgUser -UserId $assignment.PrincipalId
            $assignedUsers += $user.DisplayName
        }
        elseif ($assignment.PrincipalType -eq "Group") {
            $group = Get-MgGroup -GroupId $assignment.PrincipalId
            $assignedGroups += $group.DisplayName
        }
    }
    
    # Get app owners
    $owners = Get-MgServicePrincipalOwner -ServicePrincipalId $app.Id
    $ownerNames = if ($owners) {
        ($owners | ForEach-Object { 
            if ($_.AdditionalProperties.ContainsKey('displayName')) {
                $_.AdditionalProperties.displayName
            } else {
                $user = Get-MgUser -UserId $_.Id
                $user.DisplayName
            }
        }) -join '; '
    } else {
        # If no owners, use assigned users as owners
        if ($assignedUsers.Count -gt 0) {
            $assignedUsers -join '; '
        } else {
            "No Owner"
        }
    }
    
    # Check for SAML configuration
    $samlEnabled = $false
    $loginUrl = ""
    $logoutUrl = ""
    $preferredSsoMode = ""

    # Get the service principal's preferred SSO mode and SAML properties
    $spProperties = Get-MgServicePrincipal -ServicePrincipalId $app.Id -Property preferredSingleSignOnMode, loginUrl, logoutUrl, samlSingleSignOnSettings
    
    if ($spProperties.PreferredSingleSignOnMode -eq "saml") {
        $samlEnabled = $true
        $loginUrl = $spProperties.LoginUrl
        $logoutUrl = $spProperties.LogoutUrl
        $preferredSsoMode = "SAML"
    } elseif ($spProperties.PreferredSingleSignOnMode) {
        $preferredSsoMode = $spProperties.PreferredSingleSignOnMode
    } else {
        $preferredSsoMode = "Not Configured"
    }

    # Determine AccessByGroups value
    $accessByGroups = "No Access" # Default value if no assignments
    if ($assignedUsers.Count -gt 0 -or $assignedGroups.Count -gt 0) {
        if ($assignedGroups.Count -gt 0 -and $assignedUsers.Count -eq 0) {
            $accessByGroups = "Yes"
        }
        elseif ($assignedUsers.Count -eq 1 -and $assignedGroups.Count -eq 0) {
            $accessByGroups = "No"
        }
        else {
            $accessByGroups = "Mix"
        }
    }
    
    # Create result object
    $resultObj = [PSCustomObject]@{
        AppDisplayName = $app.DisplayName
        AppId = $app.AppId
        ObjectId = $app.Id
        Owners = $ownerNames
        SsoMode = $preferredSsoMode
        SAMLEnabled = $samlEnabled
        SAMLLoginUrl = $loginUrl
        SAMLLogoutUrl = $logoutUrl
        AccessByGroups = $accessByGroups
        AssignedUsers = ($assignedUsers -join '; ')
        AssignedGroups = ($assignedGroups -join '; ')
        UserCount = $assignedUsers.Count
        GroupCount = $assignedGroups.Count
    }
    
    # If SAML is enabled, get additional SAML details
    if ($samlEnabled) {
        $samlSettings = Get-MgServicePrincipalSamlSingleSignOnSetting -ServicePrincipalId $app.Id
        $resultObj | Add-Member -NotePropertyName 'SAMLEntityId' -NotePropertyValue $samlSettings.EntityId
        $resultObj | Add-Member -NotePropertyName 'SAMLReplyUrl' -NotePropertyValue ($samlSettings.ReplyUrls -join '; ')
    }
    
    $results += $resultObj
}

# Export to CSV
$results | Export-Csv -Path "EnterpriseApps_SAML_Inventory.csv" -NoTypeInformation

Write-Host "Export completed. File saved as EnterpriseApps_SAML_Inventory.csv"

# Display summary statistics
Write-Host "`nSummary Statistics:"
Write-Host "Total Apps: $($results.Count)"
Write-Host "SAML Enabled Apps: $(($results | Where-Object { $_.SAMLEnabled -eq $true }).Count)"
Write-Host "Apps with No Access: $(($results | Where-Object { $_.AccessByGroups -eq 'No Access' }).Count)"
Write-Host "Apps with Group-Only Access: $(($results | Where-Object { $_.AccessByGroups -eq 'Yes' }).Count)"
Write-Host "Apps with Single-User Access: $(($results | Where-Object { $_.AccessByGroups -eq 'No' }).Count)"
Write-Host "Apps with Mixed Access: $(($results | Where-Object { $_.AccessByGroups -eq 'Mix' }).Count)"
Write-Host "Apps with No Owner: $(($results | Where-Object { $_.Owners -eq 'No Owner' }).Count)"
