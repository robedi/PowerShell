# Zabbix Agent Installation Script for Windows

## Overview

This PowerShell script automates the installation and configuration of the Zabbix Agent (either classic or Agent 2) on Windows systems. It includes automatic detection of existing agent installations, optional version selection, elevated permission handling, and custom configuration updates.

## Features

* Installs either Zabbix Agent or Zabbix Agent 2 based on existing setup or user preference
* Downloads the appropriate version of the installer
* Ensures elevated privileges are used
* Verifies and installs required PowerShell modules and package providers
* Automatically generates and updates the Zabbix agent configuration file
* Starts the appropriate agent service and ensures it is running

## Parameters

| Name                 | Description                                | Default                  |
| -------------------- | ------------------------------------------ | ------------------------ |
| `ZabbixServer`       | IP address of the passive Zabbix server    | `10.30.8.4`              |
| `ZabbixServerActive` | IP address of the active Zabbix server     | `10.30.8.4`              |
| `ListenPort`         | Port the Zabbix agent listens on           | `10050`                  |
| `EnablePath`         | Whether to enable system.run\[] commands   | `1`                      |
| `AllowDenyKey`       | Allowed key rule for system.run\[]         | `AllowKey=system.run[*]` |
| `HostMetaData`       | Metadata for host registration             | `Windows clients`        |
| `ForceAgent`         | Force installation of `Agent1` or `Agent2` | *(auto-detect)*          |

## Usage

Run the script with optional parameters:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install-ZabbixAgent.ps1 -ZabbixServer "10.1.1.100" -ForceAgent "Agent2"
```

Or double-click it as Administrator.

> ⚠️ The script will automatically relaunch itself in an elevated PowerShell console if not already run as administrator.

## How It Works

1. **Elevation Check**: If not run as Administrator, it relaunches itself elevated.
2. **Parameter Handling**: Supports both auto-detection of installed agents and forced agent type.
3. **Dependency Setup**:

   * Installs `PackageManagement` module if missing.
   * Ensures `NuGet` provider is available.
4. **Directory Preparation**: Creates `C:\Tools` if it doesn’t exist.
5. **Download**:

   * Determines architecture (x86 or x64)
   * Downloads correct installer from Zabbix CDN
   * Downloads the appropriate configuration template from GitHub
6. **Installation**:

   * Stops any running Zabbix Agent service
   * Installs the agent using silent MSI arguments
7. **Configuration**:

   * Replaces the default config with downloaded template
   * Injects custom values for Server IPs, HostInterface, Hostname, and Metadata
8. **Service Start**:

   * Starts the appropriate Zabbix Agent service and ensures it is running

## Requirements

* Windows 10/11 or Windows Server 2016+
* PowerShell 5.1 or later
* Internet connectivity for downloads
* Administrative privileges

## Notes

* The script will overwrite the existing Zabbix config file with a new one from the GitHub template.
* The installation supports `amd64` and `i386` architectures.

## Author

**RoBeDi** – [GitHub Repository](https://github.com/RoBeDi/PowerShell)

## License

MIT License