# AutomatingUpgrades

## Guidelines: How the Octopus Deployment Upgrade Script Works

This PowerShell script is designed to automate the process of upgrading an **Octopus Deploy** server. It covers downloading the latest version of Octopus, placing the server into maintenance mode, backing up relevant data, running the upgrade, and then taking the server out of maintenance mode once the upgrade is complete.

Below is a breakdown of how each part of the script works:

---
### **Note**
   - If you use a network share for storing backups, make sure to add the Octopus Deploy computer account to the network share with Full Control permissions.
   - Test the upgrade process, using this script, on a test instance or server. After successful testing, perform the upgrade process on the main instance.
   - If you need to verify that Octopus Deploy is working as expected, comment out the function `Set-OctopusOutOfMaintenanceMode` (line 276) to prevent automatic disabling of the maintenance mode.
   - The module SqlServer will be installed and imported, if it is not present on the Octopus Deploy server. This is required to backup the database.

### 1. **Setup Configuration**
Several variables are set at the beginning of the script. You'll need to replace placeholders with actual values for your environment.

- **$url**: The URL of your Octopus Deploy Web Portal. Replace `'https://samples.octopus.app'` with your production URL.
- **$apiKey**: This is your Octopus API key. You must provide the correct API key to allow the script to interact with the Octopus server.
- **$octopusDeployDatabaseName**: The name of your Octopus database. Default is `"OctopusDeploy"`, but you can change this if your database is named differently.
- **$sqlBackupFolderLocation**: The location where the database backup will be stored.
- **$fileBackupLocation**: The location where important files (logs, artifacts, telemetry) will be backed up.
- **$downloadDirectory**: Directory where the MSI file (Octopus installer) will be downloaded. You can use a network share or the local temp directory (`${env:Temp}`).

### 2. **Get Latest Version Information**
The script retrieves the current version of Octopus running on your server and checks for the latest available version from Octopus Deploy's download site.

```powershell
$currentVersion = (Invoke-RestMethod "$Url/api").Version
$versions = Invoke-RestMethod "https://octopus.com/download/upgrade/v3"
$upgradeVersion = $versions[-1].Version
```

This part sets `$currentVersion` and `$upgradeVersion`. If the current version matches the latest version, the script exits. Otherwise, it proceeds with the upgrade.

### 3. **Maintenance Mode (Retry Logic)**
The function `Set-OctopusOutOfMaintenanceMode` attempts to take the server out of maintenance mode. It has built-in retry logic to ensure the server is successfully taken out of maintenance mode.

This function is used later to place the server back into maintenance mode and after the upgrade to exit maintenance mode.

### 4. **Download the MSI Installer**
The script downloads the Octopus upgrade MSI file only if it doesn't already exist in the specified `$downloadDirectory`.

```powershell
if (-Not (Test-Path $destinationPath)) {
    Write-Host "Downloading $msiFilename"
    Start-BitsTransfer -Source "https://download.octopusdeploy.com/octopus/$msiFilename" -Destination "$downloadDirectory\$msiFilename"
}
```

### 5. **Backing Up Server Folders**
If the upgrade is a major version change, the script performs backups of key folders, such as logs, artifacts, telemetry, and packages, using the `robocopy` command. Before performing the backup, it will check if the directory is present. If not, it will skip to the next command. Not every version has or uses the same server folder structure.

```powershell
if ($versionSplit[0] -ne $upgradeSplit[0]) {
    # Backup using robocopy
}
```

This ensures that no data is lost in the event of a major upgrade.

### 6. **Backup the Database**
Before the upgrade, the script takes a backup of the Octopus Deploy database. The backup is saved in the `$sqlBackupFolderLocation`.

```powershell
$command.CommandText = "BACKUP DATABASE [$octopusDeployDatabaseName] TO DISK = '$backupFileFullPath' WITH FORMAT;"
$command.ExecuteNonQuery()
```

If the backup fails, the script stops and restarts the service.

### 7. **Run the Installer**
The script runs the MSI installer for the new Octopus version:

```powershell
$msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $msiToInstall /quiet" -Wait -PassThru).ExitCode
```

It waits for the installation to complete and captures the exit code to ensure the installation was successful.

### 8. **Upgrade the Database**
After installing the new version, the script upgrades the Octopus database schema to match the new software version.

```powershell
& $serverExe database --instance="OctopusServer" --upgrade
```

### 9. **Restart the Service**
Once the upgrade is complete, the script restarts the Octopus service to ensure everything is up and running.

```powershell
& $serverExe service --instance="OctopusServer" --start
```

### 10. **Settle Time**
The script includes a configurable pause (`$settleTimeInMinutes`, default 30 minutes) between installations to allow the server to stabilize before proceeding to the next step.

```powershell
Start-Sleep -Seconds ($settleTimeInMinutes * 60)
```

### 11. **Clean Up**
Finally, the downloaded MSI installer is deleted to free up space:

```powershell
Remove-Item "$downloadDirectory\$msiFilename"
```

---

### **Script Flow Overview:**

1. **Check for updates**: If the current version is older than the latest version, the script proceeds.
2. **Backup**: The script backs up key folders and the database.
3. **Download Installer**: The latest version of the installer is downloaded if not already present.
4. **Place in Maintenance Mode**: The server is placed in maintenance mode.
5. **Run Upgrade**: The installer is executed to perform the upgrade.
6. **Database Upgrade**: The database schema is upgraded.
7. **Restart**: The server is restarted, and the script exits maintenance mode.
8. **Clean Up**: The downloaded installer is removed.

By following this process, the script ensures a smooth, automated upgrade of the Octopus Deploy server with proper backups and safeguards.