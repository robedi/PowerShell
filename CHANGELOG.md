# Change Log
[![Changelog](https://common-changelog.org/badge.svg)](https://common-changelog.org)

All notable changes to this repository will be documented in this file.

## 2025-06-29

### Added
- Added PowerShell script for importing CSV files into SQL Database

## 2024-10-09

### Added
- Added Zabbix Agent configuration file for Intune deployments
- Added Rosetta 2 script for macOS machines managed using Intune

### Changed
- Updated the process for installing and configuring the Zabbix Agent on Microsoft-based machines
- Script is no longer depended on a onpremise file share and will download the template file from GitHub
  - [Install-ZabbixAgent-Intune.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Zabbix/Install-ZabbixAgent-Intune.ps1) for Intune-enrolled machines

## 2024-09-30

### Added
- Added new script for resetting Microsoft Update on Microsoft-based machines (Windows 10 and 11)
  - [Reset-WindowsUpdate.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Microsoft/Reset-WindowsUpdate.ps1)

## 2024-09-27

### Changed
- [Install-ZabbixAgent.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Zabbix/Install-ZabbixAgent.ps1) and [Install-ZabbixAgent-Intune.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Zabbix/Install-ZabbixAgent-Intune.ps1)
  - Added command to the scripts to confirm if the script is running in elevated mode
  - Improved function blocks 'Ensure-Module' and 'Ensure-PackageProvider'

## 2024-09-26

### Added
- Added new files to automate the process for installing and configuring the Zabbix Agent on Microsoft-based machines
  - [Install-ZabbixAgent.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Zabbix/Install-ZabbixAgent.ps1) for domain-joined machines
  - [Install-ZabbixAgent-Intune.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Zabbix/Install-ZabbixAgent-Intune.ps1) for Intune-enrolled machines
 
### Changed
- Updated the Wiki page
- Added Zabbix Agent Wiki pages

## 2024-09-25

### Added
- Added new files to support the Octopus Deploy upgrade process
  - [AUTOMATINGUPGRADES.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Octopus/AutomatingUpgrades.ps1) with ([AUTOMATINGUPGRADES.md](https://github.com/RoBeDi/PowerShell/blob/master/Octopus/AUTOMATINGUPGRADES.md))
  - [AUTOMATINGSTAGEDUPGRADES.ps1](https://github.com/RoBeDi/PowerShell/blob/master/Octopus/AutomatingStagedUpgrades.ps1) with ([AUTOMATINGSTAGEDUPGRADES.md](https://github.com/RoBeDi/PowerShell/blob/master/Octopus/AUTOMATINGSTAGEDUPGRADES.md)) 

### Changed
- Reorganized files into their respective folders

### Fixed
