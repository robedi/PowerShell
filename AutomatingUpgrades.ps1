<#
    .SYNOPSIS
    This script automates the process of upgrading the Octopus Deploy server to the latest available version, with database and file 
    backups included. This script is based on the original script, available on octopus.com (https://octopus.com/docs/administration/upgrading/guide/automate-upgrades).
    
    .DESCRIPTION
    The script retrieves the latest version of the Octopus Deploy server, compares it with the current version, and performs the necessary upgrades. 
    It also handles database backups, file backups using `robocopy`, and places the Octopus server in and out of maintenance mode. 
    Additionally, it includes retry logic for placing Octopus out of maintenance mode in case of network or server issues.
    
    .VARIABLE url
    The URL of your Octopus Deploy portal.

    .VARIABLE apiKey
    The API key to authenticate with the Octopus Deploy API.

    .VARIABLE octopusDeployDatabaseName
    The name of the Octopus Deploy SQL database.

    .VARIABLE sqlBackupFolderLocation
    The network share location where the SQL database backups will be stored.

    .VARIABLE fileBackupLocation
    The network share location where file backups will be stored using `robocopy`.

    .VARIABLE downloadDirectory
    The location where the Octopus Deploy MSI installer files will be downloaded.

    .EXAMPLE
    # Run the script to upgrade Octopus Deploy to the latest version, using one of the following commands:
    .\AutomatingUpgrades.ps1
    PowerShell.exe -ExecutionPolicy Bypass -File .\AutomatingUpgrades.ps1

    .INPUTS
    None. This script does not take piped input.

    .OUTPUTS
    Outputs the progress of each operation to the console.

    .NOTES
        File Name    : AutomatingUpgrades
        Created by   : Roland van 't Kruijs
        Date Coded   : 09/24/2024 21:01:32

    .LINK
    https://github.com/RoBeDi/PowerShell
#>

$url = 'https://samples.octopus.app' # TO DO: Change this to your production Octopus Web Portal URL
$apiKey = "YOUR_API_KEY" # TO DO: Provide your API key
$octopusDeployDatabaseName = "OctopusDeploy" # TO DO: Change the database name, if it is different from the default
$sqlBackupFolderLocation = "\\ServerStorage\Share\DatabaseBackup" # TO DO: Provide the network share to store the database backup
$fileBackupLocation = "\\ServerStorage\Share\FileBackup" # TO DO: Provide the network share to store the file backup
$downloadDirectory = "${env:Temp}" # TO DO: Alternatively, change and provide the network share where the Octopus update files are located.

# This is the default install location, but yours could be different
$installPath = "${env:ProgramFiles}\Octopus Deploy\Octopus"
$serverExe = "$installPath\Octopus.Server.Exe"

# Get the latest minor/patch version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$currentVersion = (Invoke-RestMethod "$Url/api").Version
$versions = Invoke-RestMethod "https://octopus.com/download/upgrade/v3"
$upgradeVersion = $versions[-1].Version

# Function to place Octopus out of maintenance mode with retry logic
function Set-OctopusOutOfMaintenanceMode {
    param(
        [string]$url,
        [string]$apiKey,
        [int]$maxRetries = 5, # Number of retries before giving up
        [int]$retryDelaySeconds = 60 # Delay between retries in seconds
    )

    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            Write-Host "Attempting to place Octopus out of maintenance mode (Attempt $($retryCount + 1) of $maxRetries)..."
            if ((Invoke-RestMethod -Uri "$url/api/maintenanceconfiguration" -Headers @{'X-Octopus-ApiKey' = $apiKey}).IsInMaintenanceMode) {
                Invoke-RestMethod `
                    -Method Put `
                    -Uri "$url/api/maintenanceconfiguration" `
                    -Headers @{'X-Octopus-ApiKey' = $apiKey} `
                    -Body (@{ Id = "maintenance"; IsInMaintenanceMode = $false } | ConvertTo-Json)
                Write-Host "Octopus is successfully out of maintenance mode." -ForegroundColor Green
                $success = $true
            } else {
                Write-Host "Octopus is already out of maintenance mode." -ForegroundColor Yellow
                $success = $true
            }
        }
        catch {
            Write-Host "Failed to connect to the server. Error: $_" -ForegroundColor Red
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "Retrying in $retryDelaySeconds seconds..."
                Start-Sleep -Seconds $retryDelaySeconds
            } else {
                Write-Host "Maximum retry attempts reached. Could not exit maintenance mode." -ForegroundColor Red
                Exit 1
            }
        }
    }
}

cls

if ($upgradeVersion -eq $currentVersion) {
    Write-Host "No new versions found. Quitting..."
    exit
} else {
    Write-Host "Version $upgradeVersion available for update..."
}

# Download the installer
$msiFilename = "Octopus.$upgradeVersion-x64.msi"
$destinationPath = "$downloadDirectory\$msiFilename"

if (-Not (Test-Path $destinationPath)) {
    Write-Host "Downloading $msiFilename"
    Start-BitsTransfer -Source "https://download.octopusdeploy.com/octopus/$msiFilename" -Destination "$downloadDirectory\$msiFilename"
} else {
    Write-Host "File already exists. No download needed."
}

# Place Octopus into maintenance mode
if (-not (Invoke-RestMethod -Uri "$url/api/maintenanceconfiguration" -Headers @{'X-Octopus-ApiKey' = $apiKey}).IsInMaintenanceMode) {
    Invoke-RestMethod `
        -Method Put `
        -Uri "$url/api/maintenanceconfiguration" `
        -Headers @{'X-Octopus-ApiKey' = $apiKey} `
        -Body (@{ Id = "maintenance"; IsInMaintenanceMode = $true } | ConvertTo-Json)
}

$versionSplit = $currentVersion -Split "\."
$upgradeSplit = $upgradeVersion -Split "\."

if ($versionSplit[0] -ne $upgradeSplit[0])
{
    Write-Host "Major version upgrade has been detected, backing up all the folders"

    $serverFolders = Invoke-RestMethod -Uri "$url/api/configuration/server-folders/values" -Headers @{'X-Octopus-ApiKey' = $apiKey}

    if ($($serverFolders.ArtifactsDirectory)) {
        $msiExitCode = (Start-Process -FilePath "robocopy" -ArgumentList "$($serverFolders.ArtifactsDirectory) $fileBackupLocation\Artifacts /mir" -Wait -PassThru).ExitCode
        
        if ($msiExitCode -ge 8) 
        {
            Throw "Unable to copy files to $fileBackupLocation\Artifacts"
        }
    }

    if ($($serverFolders.EventExportsDirectory)) {
        $msiExitCode = (Start-Process -FilePath "robocopy" -ArgumentList "$($serverFolders.EventExportsDirectory) $fileBackupLocation\EventExports /mir" -Wait -PassThru).ExitCode
    
        if ($msiExitCode -ge 8) 
        {
            Throw "Unable to copy files to $fileBackupLocation\EventExports"
        }
    }

    if ($($serverFolders.PackagesDirectory)) {
        $msiExitCode = (Start-Process -FilePath "robocopy" -ArgumentList "$($serverFolders.PackagesDirectory) $fileBackupLocation\Packages /mir" -Wait -PassThru).ExitCode
    
        if ($msiExitCode -ge 8) 
        {
            Throw "Unable to copy files to $fileBackupLocation\Packages"
        }
    }

    if ($($serverFolders.LogsDirectory)) {
        $msiExitCode = (Start-Process -FilePath "robocopy" -ArgumentList "$($serverFolders.LogsDirectory) $fileBackupLocation\TaskLogs /mir" -Wait -PassThru).ExitCode
    
        if ($msiExitCode -ge 8) 
        {
            Throw "Unable to copy files to $fileBackupLocation\TaskLogs"
        }
    }

    if ($($serverFolders.TelemetryDirectory)) {
        $msiExitCode = (Start-Process -FilePath "robocopy" -ArgumentList "$($serverFolders.TelemetryDirectory) $fileBackupLocation\Telemetry /mir" -Wait -PassThru).ExitCode
    
        if ($msiExitCode -ge 8) 
        {
            Throw "Unable to copy files to $fileBackupLocation\Telemetry"
        }
    }
}

# Finish any remaining tasks and stop the service
& $serverExe node --instance="OctopusServer" --drain=true --wait=0
& $serverExe service --instance="OctopusServer" --stop

# Check if the SqlServer module is installed
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "SqlServer module not found. Installing the module..." -ForegroundColor Yellow

    # Install the SqlServer module from the PowerShell Gallery
    Install-Module -Name SqlServer -Force -AllowClobber

    Write-Host "SqlServer module installed successfully." -ForegroundColor Green
} else {
    Write-Host "SqlServer module is already installed." -ForegroundColor Green
}

# Import the SqlServer module
Write-Host "Importing the SqlServer module..."
Import-Module -Name SqlServer

# Verify that the module was imported successfully
if (Get-Module -Name SqlServer) {
    Write-Host "SqlServer module imported successfully." -ForegroundColor Green
} else {
    Write-Host "Failed to import the SqlServer module." -ForegroundColor Red
    Write-Host "Try to fix the issue first and re-run the script. Exiting now in 5 seconds..."
    Start-Sleep -Seconds 5
    Exit
}

try{
    # Backup database
    $backupFileName = "$octopusDeployDatabaseName_" + (Get-Date -Format FileDateTime) + '.bak'
    $backupFileFullPath = "$sqlBackupFolderLocation\$backupFileName"

    # OctopusServer is the default instance name.  If you have multiple instances, or are not using the default instance name, change the --instance parameter.
    $instanceConfig = (& $serverExe show-configuration --instance="OctopusServer" --format="JSON") | Out-String | ConvertFrom-Json
    
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $instanceConfig.'Octopus.Storage.ExternalDatabaseConnectionString'

    $command = $sqlConnection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]'Text'
    $command.CommandTimeout = 0

    Write-Host "Opening the connection"
    $sqlConnection.Open()

    Write-Host "Creating backup of $octopusDeployDatabaseName database"
    $command.CommandText = "BACKUP DATABASE [$octopusDeployDatabaseName] TO DISK = '$backupFileFullPath' WITH FORMAT;"
    $command.ExecuteNonQuery()

    Write-Host "Successfully backed up the database $octopusDeployDatabaseName"
    Write-Host "Closing the connection"
    $sqlConnection.Close()
}
catch {
    Write-Error $_.Exception

    & $serverExe service --instance="OctopusServer" --start
    & $serverExe node --instance="OctopusServer" --drain=false

    # Place Octopus out of maintenance mode
    Set-OctopusOutOfMaintenanceMode -url $url -apiKey $apiKey # Placing Octopus out of maintenance mode

    exit 1
}

# Running the installer
$msiToInstall = "$downloadDirectory\$msiFilename"
Write-Host "Installing $msiToInstall"
$msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $msiToInstall /quiet" -Wait -PassThru).ExitCode
Write-Output "Server MSI installer returned exit code $msiExitCode" 

# Upgrade database and restart service
# OctopusServer is the default instance name.  If you have multiple instances, or are not using the default instance name, change the --instance parameter.
& $serverExe database --instance="OctopusServer" --upgrade
& $serverExe service --instance="OctopusServer" --start
& $serverExe node --instance="OctopusServer" --drain=false

# Waiting for Octopus to settle down
Start-Sleep -Seconds 10

# Usage of the function after each upgrade
Set-OctopusOutOfMaintenanceMode -url $url -apiKey $apiKey # Placing Octopus out of maintenance mode

Remove-Item "$downloadDirectory\$msiFilename"