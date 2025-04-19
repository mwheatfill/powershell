# Start timing
$scriptStartTime = Get-Date

# Install and import modules if needed
# Install-Module Microsoft.Graph -Scope CurrentUser -Force
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "User.ReadBasic.All", "GroupMember.Read.All" -NoWelcome

# Get VPN group IDs
$vpnGroups = @(
    "DFCU GP DUO SSO",
    "Define GP DUO SSO",
    "STS GP DUO SSO",
    "GP3 DUO SSO"
) | ForEach-Object {
    Get-MgGroup -Filter "displayName eq '$_'"
}

# Get all active users with employeeId
$users = Get-MgUser -Filter "accountEnabled eq true and employeeId ne null" `
    -Property DisplayName, UserPrincipalName, JobTitle, Department, Id, CompanyName, CreatedDateTime, EmployeeId, OfficeLocation `
    -CountVariable CountVar `
    -ConsistencyLevel eventual `
    -All

# Create an array to hold the user data for CSV
$userData = foreach ($user in $users) {
    try {
        Write-Host "Processing data for: $($user.DisplayName)"
        
        # Get manager (suppress error output)
        $manager = Get-MgUserManager -UserId $user.Id -ErrorAction SilentlyContinue
        
        # Get direct report count
        $directReports = Get-MgUserDirectReport -UserId $user.Id
        $directReportCount = if ($directReports) { @($directReports).Count } else { 0 }
        
        # Check VPN group membership across all VPN groups
        $isVpnUser = $false
        foreach ($vpnGroup in $vpnGroups) {
            $groupMembers = Get-MgGroupMember -GroupId $vpnGroup.Id
            if ($groupMembers | Where-Object { $_.Id -eq $user.Id }) {
                $isVpnUser = $true
                break  # Exit the loop once we find membership in any group
            }
        }
        
        # Standardize Organization name
        $organization = switch -Wildcard ($user.CompanyName) {
            "Desert*" { "Desert Financial" }
            "Define*" { "Desert Financial" }
            "SwitchThink*" { "SwitchThink" }
            default { $user.CompanyName }
        }
        
        # Only create object if manager exists
        if ($manager) {
            [PSCustomObject]@{
                DisplayName = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                JobTitle = $user.JobTitle
                Department = $user.Department
                Organization = $organization
                OfficeLocation = $user.OfficeLocation
                ApproximateHireDate = $user.CreatedDateTime.ToString('yyyy-MM-dd')
                DirectReportCount = $directReportCount
                IsVpnUser = $isVpnUser
                ManagerName = $manager.AdditionalProperties.displayName
                ManagerUPN = $manager.AdditionalProperties.userPrincipalName
            }
            Write-Host "Added $($user.DisplayName) to export list" -ForegroundColor Green
        }
        else {
            Write-Host "Skipping $($user.DisplayName) - no manager found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error processing user $($user.DisplayName): $_" -ForegroundColor Red
    }
}

# Export to CSV
$userData | Export-Csv -Path "UserData.csv" -NoTypeInformation

# Calculate execution time
$scriptEndTime = Get-Date
$executionTime = $scriptEndTime - $scriptStartTime

Write-Host "`nProcess completed! CSV has been saved." -ForegroundColor Green
Write-Host "Total users with managers: $($userData.Count)" -ForegroundColor Cyan
Write-Host "Total users queried: $CountVar" -ForegroundColor Cyan
Write-Host "Script execution time: $($executionTime.Minutes) minutes $($executionTime.Seconds) seconds" -ForegroundColor Cyan