#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
<#
    .SYNOPSIS
    This script automates the installation and configuration of the Zabbix Agent on a Windows machine.

    .DESCRIPTION
    The script ensures all required dependencies are met, downloads the correct version of the Zabbix Agent, 
    stops and starts the Zabbix service, and updates its configuration file. It includes functions to handle 
    service management, package installation, and configuration updates.

    .PARAMETER ZabbixServer
    The IP address of the Zabbix server. Default is '10.30.8.4'.

    .PARAMETER ZabbixServerActive
    The IP address for active Zabbix server checks. Default is '10.30.8.4'.

    .PARAMETER ListenPort
    The port on which the Zabbix agent listens. Default is '10050'.

    .PARAMETER EnablePath
    Enables or disables the Path for the system.run[] key. Default is '1'.

    .PARAMETER AllowDenyKey
    Specifies allowed keys for the Zabbix agent. Default is 'AllowKey=system.run[*]'.

    .PARAMETER HostMetaData
    Metadata for the host. Default is 'Windows clients'.

    .EXAMPLE
    .\Install-ZabbixAgent-Online.ps1
    Powershell -ExecutionPolicy ByPass -File ".\Install-ZabbixAgent-Online.ps1"

    .INPUTS
    None. The script does not accept pipeline input.

    .OUTPUTS
    Outputs status messages to the console during execution.

    .NOTES
        FunctionName : Install-ZabbixAgent-Online
        Created by   : RoBeDi
        Date Coded   : 02/07/2025 10:10:41
    .LINK
        https://github.com/RoBeDi/PowerShell
 #>

[CmdletBinding()]
param (
[Parameter()]
[string]$ZabbixServer = '10.30.8.4',
[Parameter()]
[string]$ZabbixServerActive = '10.30.8.4',
[Parameter()]
[string]$ListenPort = '10050',
[Parameter()]
[string]$EnablePath = '1',
[Parameter()]
[string]$AllowDenyKey = 'AllowKey=system.run[*]',
[Parameter()]
[string]$HostMetaData = 'Windows clients',
[ValidateSet("Agent1", "Agent2")]
[string]$ForceAgent
)

cls

# Relaunch in elevated ISE if not already running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires elevated privileges (Run as Administrator). Relaunching in elevated PowerShell console..."
    
    $script = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$script`""
    exit
}

# Variables
$version = "7.4.0"
$release = $version
$shortVersion = ($version -split '\.')[0..1] -join '.'
$toolsPath = "C:\Tools"
$agent1Service = "Zabbix Agent"
$agent2Service = "Zabbix Agent 2"
$agent1Path = "C:\Program Files\Zabbix Agent\zabbix_agentd.exe"
$agent2Path = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe"
$agentConfFile1 = "C:\Program Files\Zabbix Agent\zabbix_agentd.conf"
$agentConfFile2 = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf"
$templateUri = "https://github.com/RoBeDi/PowerShell/raw/refs/heads/master/Zabbix/Intune/template_zabbix_agentd.conf"
$templateUri2 = "https://github.com/RoBeDi/PowerShell/raw/refs/heads/master/Zabbix/Intune/template_zabbix_agent2.conf"
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") { "amd64" } else { "i386" }

function Stop-ZabbixAgentService {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    
    # Check if the service exists
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Host "Service $ServiceName does not exist. Skipping..." -ForegroundColor Red
        return
    }
    
    # Stop the service
    Write-Host "Stopping the service: $ServiceName"
    Stop-Service -Name $ServiceName -Force

    # Confirm the service has stopped
    $service = Get-Service -Name $ServiceName
    while ($service.Status -ne 'Stopped') {
        Write-Host "Waiting for service to stop..."
        Start-Sleep -Seconds 2
        $service = Get-Service -Name $ServiceName
    }
    Write-Host "Service $ServiceName has stopped."
}

function Start-ZabbixAgentService {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    
    # Start the service
    Write-Host "Starting the service: $ServiceName"
    Start-Service -Name $ServiceName

    # Confirm the service has started
    $service = Get-Service -Name $ServiceName
    while ($service.Status -ne 'Running') {
        Write-Host "Waiting for service to start..."
        Start-Sleep -Seconds 2
        Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
        $service = Get-Service -Name $ServiceName
    }
    Write-Host "Service $ServiceName is running."
}

function Ensure-Module {
    param (
        [string]$ModuleName
    )

    $module = Get-Module -ListAvailable -Name $ModuleName
    if ($null -eq $module) {
        Write-Output "Installing module $ModuleName..."
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
    } else {
        $latestVersion = Find-Module -Name $ModuleName | Select-Object -ExpandProperty Version
        $installedVersion = $module.Version

        if ($installedVersion -lt $latestVersion) {
            Write-Output "Updating module $ModuleName from version $installedVersion to $latestVersion..."
            Update-Module -Name $ModuleName -Force #-Scope CurrentUser
        } else {
            Write-Output "Module $ModuleName is up-to-date (version $installedVersion)."
        }
    }
}

function Ensure-PackageProvider {
    param (
        [string]$ProviderName,
        [string]$MinimumVersion
    )

    $installedProvider = Get-PackageProvider -Name $ProviderName -ErrorAction SilentlyContinue
    if ($null -eq $installedProvider -or $installedProvider.Version -lt $MinimumVersion) {
        Write-Host "Installing/Updating $ProviderName to at least version $MinimumVersion..."
        Install-PackageProvider -Name $ProviderName -MinimumVersion $MinimumVersion -Force -Confirm:$false
    } else {
        Write-Host "$ProviderName is already installed and meets the minimum version requirement."
    }
}

cls
Write-Host "STATUS:"
Write-Host " "
Write-Host "Script started at $(Get-Date)"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Ensure-Module -ModuleName "PowerShellGet"
Ensure-Module -ModuleName "PackageManagement"
Ensure-PackageProvider -ProviderName "NuGet" -MinimumVersion $nuGetProviderMinVersion

if (-not (Test-Path -Path $toolsPath -PathType Container)) {
    New-Item -Path $toolsPath -ItemType Directory -Force | Out-Null
    Write-Host "Directory created: $toolsPath"
} else {
    Write-Host "Directory already exists: $toolsPath"
}

$HostInterface = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.AddressState -eq "Preferred" -and ($_.ValidLifetime -lt "24:00:00" -or $_.PrefixOrigin -eq "Dhcp") }).IPAddress
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$Model = $osInfo.ProductType

# Detect installed agent
$installedAgent = if (Get-Service -Name $agent2Service -ErrorAction SilentlyContinue) {
    "Agent2"
} elseif (Get-Service -Name $agent1Service -ErrorAction SilentlyContinue) {
    "Agent1"
} else {
    "None"
}

if ($ForceAgent) {
    $preferredAgent = $ForceAgent
} elseif ($installedAgent -ne "None") {
    $preferredAgent = $installedAgent
} else {
    $preferredAgent = "Agent2"
}

function Configure-ZabbixAgent {
    param (
        [string]$ConfigPath
    )

    $ConfigContent = Get-Content $ConfigPath

    if ($HostInterface -like '10.145.*' -and $Model -eq '3') {
        $meta = 'Windows servers'
        $ip = '10.145.162.105'
    } elseif ($HostInterface -like '10.30.*' -and $Model -eq '3') {
        $meta = 'Windows servers'
        $ip = '10.30.8.4'
    } else {
        $meta = 'Windows clients'
        $ip = '10.145.162.105'
    }

    $ConfigContent | ForEach-Object {
        if ($_ -eq "Server=") {
            $ConfigContent[$ConfigContent.IndexOf($_)] += $ip
        }
        if ($_ -eq "ServerActive=") {
            $ConfigContent[$ConfigContent.IndexOf($_)] += $ip
        }
        if ($_ -eq "HostInterface=") {
            $ConfigContent[$ConfigContent.IndexOf($_)] += $HostInterface
        }
        if ($_ -eq "Hostname=") {
            $ConfigContent[$ConfigContent.IndexOf($_)] += $env:COMPUTERNAME
        }
        if ($_ -eq "HostMetaData=") {
            $ConfigContent[$ConfigContent.IndexOf($_)] += $meta
        }
    }

    Set-Content $ConfigPath -Value $ConfigContent
    Write-Host " DONE" -ForegroundColor Green
}

function Install-ZabbixAgent1 {
    Stop-ZabbixAgentService -ServiceName "Zabbix Agent"
    Write-Host "Installing Zabbix Agent..." -NoNewline
    $msi = "$env:TEMP\ZabbixAgent-v$version.msi"
    $uri = "https://cdn.zabbix.com/zabbix/binaries/stable/$shortVersion/$version/zabbix_agent-$version-windows-$arch-openssl.msi"
    Invoke-WebRequest -Uri $uri -OutFile $msi
    Start-Process -FilePath $msi -ArgumentList "/qn SERVER=$ZabbixServer SERVERACTIVE=$ZabbixServerActive HOSTNAME=$env:COMPUTERNAME ListenPort=$ListenPort EnablePath=$EnablePath" -Wait
    Invoke-WebRequest -Uri $templateUri -OutFile "$env:TEMP\template_zabbix_agentd.conf"
    Remove-Item -Path $agentConfFile1 -Force -ErrorAction SilentlyContinue
    Copy-Item "$env:TEMP\template_zabbix_agentd.conf" -Destination $agentConfFile1 -Force
    Configure-ZabbixAgent -ConfigPath $agentConfFile1
    Write-Host "Zabbix installation completed. Starting agent service..."
    Start-Sleep -Seconds 10
    Start-ZabbixAgentService -ServiceName "Zabbix Agent"
}

function Install-ZabbixAgent2 {
    Stop-ZabbixAgentService -ServiceName "Zabbix Agent 2"
    Write-Host "Installing Zabbix Agent 2..." -NoNewline
    $msi = "$toolsPath\ZabbixAgent2-v$version.msi"
    $uri = "https://cdn.zabbix.com/zabbix/binaries/stable/$shortVersion/$version/zabbix_agent2-$version-windows-$arch-openssl.msi"
    Invoke-WebRequest -Uri $uri -OutFile $msi
    Start-Process -FilePath $msi -ArgumentList "/qn SERVER=$ZabbixServer SERVERACTIVE=$ZabbixServerActive HOSTNAME=$env:COMPUTERNAME ListenPort=$ListenPort EnablePath=$EnablePath" -Wait
    Invoke-WebRequest -Uri $templateUri2 -OutFile "$env:TEMP\template_zabbix_agent2.conf"
    Remove-Item -Path $agentConfFile2 -Force -ErrorAction SilentlyContinue
    Copy-Item "$env:TEMP\template_zabbix_agent2.conf" -Destination $agentConfFile2 -Force
    Configure-ZabbixAgent -ConfigPath $agentConfFile2
    Write-Host "Zabbix installation completed. Starting agent service..."
    Start-Sleep -Seconds 10
    Start-ZabbixAgentService -ServiceName "Zabbix Agent 2"
}

switch ($preferredAgent) {
    "Agent1" { Install-ZabbixAgent1 }
    "Agent2" { Install-ZabbixAgent2 }
    default {
        Write-Error "Unsupported agent type: $preferredAgent"
        exit 1
    }
}

Write-Host "Agent service should now be running. Script will close in 10 seconds."
Start-Sleep -Seconds 10
Stop-Process -Id $PID