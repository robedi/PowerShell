# AutomatingStagedUpgrades

## Guidelines on How the Octopus Deploy Upgrade Script Works

This script automates the process of upgrading an Octopus Deploy server by downloading and applying a series of update files in a staged, incremental manner. The script ensures that the system is properly backed up before performing updates, places the server in maintenance mode during the upgrade process, and manages system restarts and maintenance status after each version upgrade.

### **Note**
   - If you use a network share for storing backups, make sure to add the Octopus Deploy computer account to the network share with Full Control permissions.
   - Test the upgrade process, using this script, on a test instance or server. After successful testing, perform the upgrade process on the main instance.
   - If you need to verify that Octopus Deploy is working as expected, comment out the function `Set-OctopusOutOfMaintenanceMode` (line 301) to prevent automatic disabling of the maintenance mode.
   - The module SqlServer will be installed and imported, if it is not present on the Octopus Deploy server. This is required to backup the database.

### Key Sections of the Script

1. **Variables and Configurations:**
   - `$url`: The URL for the Octopus Deploy Web Portal. You should replace `'YOUR_PORTAL_URL'` with the actual URL of your Octopus Deploy instance.
   - `$apiKey`: The API key used to authenticate requests to the Octopus Deploy server. Replace `'YOUR_API_KEY'` with your actual API key.
   - `$octopusDeployDatabaseName`: The name of the Octopus Deploy database. Change it if the database name differs from the default value.
   - `$sqlBackupFolderLocation`: The location where the database backups will be stored. This should be a network share or a local folder accessible to the script.
   - `$fileBackupLocation`: The location where file backups (logs, artifacts, etc.) will be stored. This ensures that critical Octopus server files are backed up before the upgrade.
   - `$downloadDirectory`: The directory where the MSI installer files for the updates will be downloaded. This can be a network share or a temporary local directory.
   - `$settleTimeInMinutes`: The amount of time (default: 30 minutes) that the script waits between each version upgrade to allow the Octopus server to stabilize.

2. **Current and Upgrade Version Detection:**
   The script uses `Invoke-RestMethod` to retrieve the current version of the Octopus Deploy server from its API:
   ```powershell
   $currentVersion = (Invoke-RestMethod "$Url/api").Version
   $versions = Invoke-RestMethod "https://octopus.com/download/upgrade/v3"
   $upgradeVersion = $versions[-1].Version
   ```
   This block of code identifies the current running version of Octopus and the latest available version for upgrade.

3. **Version Comparison Function:**
   The script uses the function `Compare-Version` to determine if the current version of Octopus is older than the version that will be installed. It compares the version numbers to decide if an upgrade should be applied:
   ```powershell
   function Compare-Version($currentVersion, $upgradeVersion) {
       # Logic to compare version numbers
   }
   ```
   The function returns `-1` if the current version is older, indicating that an upgrade is required.

4. **$stagedVersions:**
   `$stagedVersions` is an variable array of version files that the script will install incrementally. Each entry in the array represents a specific MSI installer file for a version of Octopus Deploy, starting with the oldest update:
   ```powershell
   $stagedVersions = @(
       "Octopus.2023.2.13580-x64.msi",
       "Octopus.2023.3.13361-x64.msi",
       "Octopus.2023.4.8624-x64.msi",
       "Octopus.2024.1.13034-x64.msi",
       "Octopus.2024.3.12741-x64.msi"
   )
   ```
   **Purpose of `$stagedVersions`:**  
   This array defines the sequence of versions to be applied to the Octopus Deploy server. The script downloads and installs each version in the list, ensuring that no update is skipped. This staged upgrade ensures the server progresses smoothly from its current version to the most recent one, handling incremental changes that may be required between major versions.

5. **Backup Process:**
   Before upgrading the server, the script checks if the version upgrade is significant (i.e., major version upgrade) and backs up the critical files, such as artifacts, logs, packages, and telemetry data. These files are copied to a backup location using `robocopy`:
   ```powershell
   Start-Process -FilePath "robocopy" -ArgumentList "$($serverFolders.ArtifactsDirectory) $fileBackupLocation\Artifacts /mir"
   ```
   The script also performs a database backup:
   ```powershell
   $command.CommandText = "BACKUP DATABASE [$octopusDeployDatabaseName] TO DISK = '$backupFileFullPath' WITH FORMAT;"
   ```

6. **Maintenance Mode:**
   The script places the Octopus Deploy server in maintenance mode before the upgrade to prevent any deployments or modifications during the upgrade process:
   ```powershell
   Invoke-RestMethod -Uri "$url/api/maintenanceconfiguration" -Headers @{'X-Octopus-ApiKey' = $apiKey} -Body (@{ Id = "maintenance"; IsInMaintenanceMode = $true } | ConvertTo-Json)
   ```
   After each upgrade step, the server is taken out of maintenance mode using the function `Set-OctopusOutOfMaintenanceMode` to allow operations to continue.

7. **Upgrading Process:**
   For each version in the `$stagedVersions` array, the script:
   - Downloads the corresponding MSI installer file if it doesn't already exist.
   - Puts the Octopus Deploy server into maintenance mode.
   - Runs the backup process (if a major upgrade is detected).
   - Stops the Octopus Deploy server, applies the MSI upgrade, and restarts the server.
   - After the upgrade, the server is taken out of maintenance mode, and the script waits for a configured period (`$settleTimeInMinutes`) to ensure the server stabilizes.

8. **Installer Execution:**
   The script runs the MSI installer file for each version, checks for errors, and handles the database upgrade step:
   ```powershell
   $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $msiToInstall /quiet" -Wait -PassThru).ExitCode 
   ```

9. **Post-Upgrade Wait:**
   After each version upgrade, the script waits for a specified period (`$settleTimeInMinutes`) to allow the server to stabilize before moving on to the next upgrade:
   ```powershell
   Start-Sleep -Seconds ($settleTimeInMinutes * 60)
   ```

10. **Error Handling:**
    If an error occurs during any step (e.g., failure to download an installer, backup issues), the script handles the error gracefully, attempts to recover, and provides meaningful messages for debugging.

### Key Takeaways:
- **Staged Upgrades:** The script performs incremental upgrades using the versions defined in `$stagedVersions`.
- **Automated Backup:** Critical files and the database are backed up before applying each version upgrade.
- **Maintenance Mode:** The server is put into and out of maintenance mode automatically during the upgrade process to ensure no disruptions occur.
- **Retry Logic:** There are retry mechanisms to handle temporary connection or API issues, ensuring the script is resilient during network interruptions.

This script automates the complex task of upgrading an Octopus Deploy server, ensuring all critical data is backed up and the server remains operational with minimal downtime during the upgrade process.