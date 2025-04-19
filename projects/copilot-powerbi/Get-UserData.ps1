# Install and import modules if needed
# Install-Module Microsoft.Graph -Scope CurrentUser -Force
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "User.ReadBasic.All"

# Get all active users (using -All parameter to get all users)
$users = Get-MgUser -Filter "accountEnabled eq true" `
    -Property DisplayName, UserPrincipalName, JobTitle, Department, Id `
    -All

# Create an array to hold the user data for CSV
$userData = foreach ($user in $users) {
    try {
        Write-Host "Processing data for: $($user.DisplayName)"
        
        # Get manager
        $manager = Get-MgUserManager -UserId $user.Id
        
        # Only create object if manager exists
        if ($manager) {
            [PSCustomObject]@{
                DisplayName = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                JobTitle = $user.JobTitle
                Department = $user.Department
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
