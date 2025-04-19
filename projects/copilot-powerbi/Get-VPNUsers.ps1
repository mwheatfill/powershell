# Connect to Microsoft Graph
Connect-MgGraph -Scopes "GroupMember.Read.All" -NoWelcome

# Define VPN groups
$vpnGroups = @(
    "DFCU GP DUO SSO",
    "Define GP DUO SSO",
    "STS GP DUO SSO",
    "GP3 DUO SSO"
) | ForEach-Object {
    Get-MgGroup -Filter "displayName eq '$_'"
}

# Get all unique members from VPN groups
$vpnUsers = @{}
foreach ($group in $vpnGroups) {
    Write-Host "Processing group: $($group.DisplayName)"
    $members = Get-MgGroupMember -GroupId $group.Id -Property userPrincipalName -All
    Write-Host "Found $($members.Count) members"
    foreach ($member in $members) {
        if ($member.AdditionalProperties.userPrincipalName) {
            $vpnUsers[$member.AdditionalProperties.userPrincipalName] = $true
        }
    }
}

Write-Host "Total unique VPN users found: $($vpnUsers.Count)"

# Export unique UPNs to CSV
$vpnUsers.Keys | Select-Object @{N='UserPrincipalName';E={$_}} | 
    Export-Csv -Path "VpnUsers.csv" -NoTypeInformation
