
# Get all Enterprise Applications (Service Principals)
$servicePrincipals = Get-MgServicePrincipal -All -Filter "tags/any(t: t eq 'WindowsAzureActiveDirectoryIntegratedApp')"

# Create a results array
$results = @()

foreach ($sp in $servicePrincipals) {
    Write-Host "Checking: $($sp.DisplayName)"

    # Get App Role Assignments (users, groups, service principals)
    $assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue

    foreach ($assignment in $assignments) {
        # Only interested in groups
        $principal = Get-MgDirectoryObject -DirectoryObjectId $assignment.PrincipalId -ErrorAction SilentlyContinue

        if ($principal.'@odata.type' -eq "#microsoft.graph.group") {
            # Resolve group name
            $group = Get-MgGroup -GroupId $assignment.PrincipalId -ErrorAction SilentlyContinue

            # Resolve role name (some may just be default access)
            $appRole = $null
            if ($assignment.AppRoleId -ne [guid]::Empty) {
                $appRole = ($sp.AppRoles | Where-Object { $_.Id -eq $assignment.AppRoleId }).DisplayName
            }

            $results += [PSCustomObject]@{
                ApplicationName = $sp.DisplayName
                AppObjectId     = $sp.Id
                GroupName       = $group.DisplayName
                GroupId         = $group.Id
                RoleAssigned    = if ($appRole) { $appRole } else { "Default Access (No Role)" }
            }
        }
    }
}

# Export the results
$results | Export-Csv -Path ".\AppGroupAssignments.csv" -NoTypeInformation
Write-Host "Export complete: AppGroupAssignments.csv"