$xmlPath = ".\GPResult.xml"
[xml]$xml = Get-Content $xmlPath

# Create array to store results
$results = @()

# Create a hashtable to store policy counts per GPO
$gpoPolicyCounts = @{}

# Count policies for each GPO
$policies = $xml.SelectNodes("//*[local-name()='Policy']")
foreach ($policy in $policies) {
    $gpoId = $policy.GPO.Identifier.'#text'
    if ($gpoId) {
        if (-not $gpoPolicyCounts.ContainsKey($gpoId)) {
            $gpoPolicyCounts[$gpoId] = 0
        }
        $gpoPolicyCounts[$gpoId]++
    }
}

# Function to check if name is a GUID
function Test-IsGuid {
    param ([string]$StringGuid)
    
    $guidPattern = '^\{?[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}?$'
    return $StringGuid -match $guidPattern
}

# Process Computer GPOs
foreach ($gpo in $xml.Rsop.ComputerResults.GPO) {
    $gpoId = $gpo.Path.Identifier.'#text'
    $settingsCount = if ($gpoPolicyCounts.ContainsKey($gpoId)) { $gpoPolicyCounts[$gpoId] } else { 0 }
    $isGuid = Test-IsGuid $gpo.Name
    
    $results += [PSCustomObject]@{
        GPOName = $gpo.Name
        Type = "Computer"
        SettingsCount = $settingsCount
        ExtensionNames = ($gpo.ExtensionName | Where-Object { $_ }) -join "; "
        Domain = $gpo.Path.Domain.'#text'
        IsGUID = $isGuid
        AccessDenied = $gpo.AccessDenied
        IsValid = $gpo.IsValid
        GPOID = $gpoId
    }
}

# Process User GPOs
foreach ($gpo in $xml.Rsop.UserResults.GPO) {
    $gpoId = $gpo.Path.Identifier.'#text'
    $settingsCount = if ($gpoPolicyCounts.ContainsKey($gpoId)) { $gpoPolicyCounts[$gpoId] } else { 0 }
    $isGuid = Test-IsGuid $gpo.Name
    
    $results += [PSCustomObject]@{
        GPOName = $gpo.Name
        Type = "User"
        SettingsCount = $settingsCount
        ExtensionNames = ($gpo.ExtensionName | Where-Object { $_ }) -join "; "
        Domain = $gpo.Path.Domain.'#text'
        IsGUID = $isGuid
        AccessDenied = $gpo.AccessDenied
        IsValid = $gpo.IsValid
        GPOID = $gpoId
    }
}

# Output main results
Write-Host "Group Policy Settings Summary:`n"
$results | Where-Object { $_.SettingsCount -gt 0 } | 
    Sort-Object SettingsCount -Descending | 
    Format-Table GPOName, Type, SettingsCount, ExtensionNames -AutoSize

# Show summary
$totalSettings = ($results | Measure-Object -Property SettingsCount -Sum).Sum
$totalGPOs = $results.Count
$gposWithSettings = ($results | Where-Object { $_.SettingsCount -gt 0 }).Count

Write-Host "`nSummary:"
Write-Host "Total GPOs: $totalGPOs"
Write-Host "GPOs with settings: $gposWithSettings"
Write-Host "Total settings across all GPOs: $totalSettings"

# Show GPOs with GUID names
Write-Host "`nGPOs showing as GUIDs (potential issues):"
$results | Where-Object { $_.IsGUID } | Format-Table GPOName, Type, Domain, AccessDenied, IsValid -AutoSize

# Show access denied GPOs
Write-Host "`nGPOs with Access Denied:"
$results | Where-Object { $_.AccessDenied -eq 'true' } | Format-Table GPOName, Type, Domain -AutoSize

# Export to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = "GPO_Settings_Summary_$timestamp.csv"
$results | Sort-Object SettingsCount -Descending | Export-Csv -Path $csvPath -NoTypeInformation

# Export detailed summary for GPOs with settings
$detailedCsvPath = "GPO_Settings_Detail_$timestamp.csv"
$results | Where-Object { $_.SettingsCount -gt 0 } | 
    Sort-Object SettingsCount -Descending | 
    Select-Object GPOName, Type, SettingsCount, ExtensionNames, Domain, IsGUID, AccessDenied, IsValid, GPOID |
    Export-Csv -Path $detailedCsvPath -NoTypeInformation

Write-Host "`nExported all GPOs to: $csvPath"
Write-Host "Exported GPOs with settings to: $detailedCsvPath"
