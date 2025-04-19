# Retrieve all app registrations with their owners
$apps = Get-MgApplication -All -Property id, displayname -ExpandProperty owners -ConsistencyLevel eventual

# Initialize an array to store results
$results = @()

# Iterate through each application
foreach ($app in $apps) {
    $appId = $app.Id
    $appName = $app.DisplayName
    $ownerNames = @()

    # Check if owners exist
    if ($app.Owners.Count -gt 0) {
        foreach ($owner in $app.Owners) {
            # Retrieve owner details (handles both User and Service Principal owners)
            $ownerDetails = Get-MgUser -UserId $owner.Id -ErrorAction SilentlyContinue
            if (-not $ownerDetails) {
                $ownerDetails = Get-MgServicePrincipal -ServicePrincipalId $owner.Id -ErrorAction SilentlyContinue
            }

            # Store the owner name, or the ID if name lookup fails
            if ($ownerDetails) {
                $ownerNames += $ownerDetails.DisplayName
            } else {
                $ownerNames += "Unknown Owner ($($owner.Id))"
            }
        }
    } else {
        $ownerNames += "No Owners"
    }

    # Add result to output array
    $results += [PSCustomObject]@{
        "App ID"      = $appId
        "App Name"    = $appName
        "Owners"      = ($ownerNames -join ", ")
    }
}

$results