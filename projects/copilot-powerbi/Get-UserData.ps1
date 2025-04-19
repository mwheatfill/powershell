# Install and import modules if needed
# Install-Module Microsoft.Graph -Scope CurrentUser -Force
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "User.ReadBasic.All", "GroupMember.Read.All"

# Get VPN group ID
$vpnGroup = Get-MgGroup -Filter "displayName eq 'GP3 DUO SSO'"
$vpnGroupId = $vpnGroup.Id

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
        
        # Check VPN group membership
        $isVpnUser = Get-MgGroupMember -GroupId $vpnGroupId | Where-Object { $_.Id -eq $user.Id }
        
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
                IsVpnUser = if ($isVpnUser) { $true } else { $false }
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

Write-Host "`nProcess completed! CSV has been saved." -ForegroundColor Green
Write-Host "Total users with managers: $($userData.Count)" -ForegroundColor Cyan
Write-Host "Total users queried: $CountVar" -ForegroundColor Cyan