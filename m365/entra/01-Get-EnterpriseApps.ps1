

# Retrieve all enterprise applications (service principals)
$servicePrincipals = Get-MgServicePrincipal -All

# Create an empty array to store our report data
$results = @()

foreach ($sp in $servicePrincipals) {
    Write-Output "Processing application: $($sp.DisplayName)"

    # Retrieve owner(s) for the service principal
    $ownerNames = @()
    try {
        $owners = Get-MgServicePrincipalOwner -ServicePrincipalId $sp.Id -All
        foreach ($owner in $owners) {
            $ownerNames += $owner.DisplayName
        }
    }
    catch {
        # If no owners are found or an error occurs, mark as not available
        $ownerNames += "N/A"
    }
    
    # Initialize SSO type as Unknown
    $ssoType = "Unknown"
    
    # Attempt to check if the app is configured for SAML SSO
    try {
        # This cmdlet is available on the beta endpoint.
        $samlConfig = Get-MgServicePrincipalSamlSingleSignOnConfiguration -ServicePrincipalId $sp.Id -ErrorAction Stop
        if ($samlConfig) {
            $ssoType = "SAML"
        }
    }
    catch {
        # If no SAML config is found, check if the app indicates OIDC/OAuth configuration.
        # For example, some service principal objects include a 'preferredSingleSignOnMode' property.
        if ($sp.AdditionalProperties.ContainsKey("preferredSingleSignOnMode")) {
            if ($sp.AdditionalProperties["preferredSingleSignOnMode"] -eq "OpenIdConnect") {
                $ssoType = "OIDC/OAuth"
            }
        }
    }
    
    # Add a custom object with the collected information to our results array
    $results += [PSCustomObject]@{
        AppDisplayName       = $sp.DisplayName
        AppId                = $sp.AppId
        ServicePrincipalId   = $sp.Id
        Owners               = ($ownerNames -join "; ")
        SSOType              = $ssoType
    }
}

# Export the report to a CSV file in the current directory
$results | Export-Csv -Path "EnterpriseAppsReport.csv" -NoTypeInformation

Write-Output "Report exported to EnterpriseAppsReport.csv"