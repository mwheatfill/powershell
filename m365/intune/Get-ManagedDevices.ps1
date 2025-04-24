<#
.SYNOPSIS
    Retrieves and displays a report of managed devices from Microsoft Intune.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all managed devices, 
    and generates a report containing User Principal Name (UPN), Device Name, 
    and Operating System. The report can be displayed on the screen or exported 
    to a CSV file.

.NOTES
    Author: Michael Wheatfill (@mwheatfill)
    Date: April 22, 2025
    Requires: Microsoft.Graph PowerShell module
    Permissions: DeviceManagementManagedDevices.Read.All
#>

# Function to ensure required modules are installed and imported
function Ensure-Module {
    param (
        [string]$ModuleName,
        [string]$Scope = "CurrentUser"
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installing module $ModuleName..." -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Scope $Scope -Force
    }
    Import-Module -Name $ModuleName -ErrorAction Stop
}

# Function to connect to Microsoft Graph
function Connect-ToGraph {
    param (
        [string]$Scopes
    )
    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes $Scopes -ErrorAction Stop
    } catch {
        Write-Error "Failed to connect to Microsoft Graph. Ensure you have the required permissions."
        throw
    }
}

# Function to retrieve managed devices
function Get-ManagedDevices {
    try {
        Write-Host "Retrieving managed devices..." -ForegroundColor Yellow
        $devices = Get-MgDeviceManagementManagedDevice -All
        return $devices
    } catch {
        Write-Error "Failed to retrieve managed devices."
        throw
    }
}

# Function to generate a filtered report
function Generate-FilteredReport {
    param (
        [array]$Devices
    )
    $filteredReport = $Devices |
        Where-Object { $_.OperatingSystem -like "Windows*" -and $_.UserPrincipalName } |
        Select-Object `
            @{Name='UserPrincipalName';Expression={$_.UserPrincipalName}},
            @{Name='DeviceName';Expression={$_.DeviceName}}
    return $filteredReport
}


# Function to generate a report
function Generate-Report {
    param (
        [array]$Devices
    )
    $report = $Devices | Select-Object `
        @{Name='UserPrincipalName';Expression={$_.UserPrincipalName}},
        @{Name='DeviceName';Expression={$_.DeviceName}},
        @{Name='OperatingSystem';Expression={$_.OperatingSystem}}
    return $report
}

# Main script execution
try {
    # Step 1: Ensure the Microsoft.Graph module is installed and imported
    Ensure-Module -ModuleName "Microsoft.Graph"

    # Step 2: Connect to Microsoft Graph with the required scope
    Connect-ToGraph -Scopes "DeviceManagementManagedDevices.Read.All"

    # Step 3: Retrieve all managed devices
    $managedDevices = Get-ManagedDevices

    # Step 4: Generate the filtered report
    $filteredReport = Generate-FilteredReport -Devices $managedDevices

    # Step 5a: Display the filtered report on the screen
    Write-Host "Filtered Managed Devices Report (Windows Devices with UPN):" -ForegroundColor Green
    $filteredReport | Format-Table -AutoSize

    # Step 5b: (Optional) Export the filtered report to a CSV file
    $csvPath = ".\FilteredUserManagedDevices.csv"
    Write-Host "Exporting filtered report to $csvPath..." -ForegroundColor Yellow
    $filteredReport | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Filtered report exported successfully to $csvPath." -ForegroundColor Green

} catch {
    Write-Error "An error occurred: $_"
}