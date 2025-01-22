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
    .\Install-ZabbixAgent-v1.ps1

    .INPUTS
    None. The script does not accept pipeline input.

    .OUTPUTS
    Outputs status messages to the console during execution.

    .NOTES
        FunctionName : Install-ZabbixAgent-v1
        Created by   : admin.roland
        Date Coded   : 06/17/2024 08:17:41
    .LINK
        https://confluence.valtech.com/display/DID/Install-ZabbixAgent-v1
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
[string]$HostMetaData = 'Windows clients'
)

$maximumfunctioncount = 32768
$HostInterface = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.AddressState -eq "Preferred" -and ($_.ValidLifetime -lt "24:00:00" -or $_.PrefixOrigin -eq "Dhcp") }).IPAddress
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$Model = $osInfo.ProductType
$ServiceName = 'Zabbix Agent'
$version = "7.2.2"
$packageManagementMinVersion = "1.4.7"
$powerShellGetMinVersion = "2.0.0"
$nuGetProviderMinVersion = "2.8.5.201"
$AgentConfFile = "C:\Program Files\Zabbix Agent\zabbix_agentd.conf"
$templatePath = "\\DK-CPH-FILE\Zabbix\template_zabbix_agentd.conf" 

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
    } else {
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
        Install-Module -Name $ModuleName -Force -AllowClobber
    } else {
        $latestVersion = Find-Module -Name $ModuleName | Select-Object -ExpandProperty Version
        $installedVersion = $module.Version

        if ($installedVersion -lt $latestVersion) {
            Write-Output "Updating module $ModuleName from version $installedVersion to $latestVersion..."
            Update-Module -Name $ModuleName -Force
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

# Check if the script is running in elevated mode (as Administrator)
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires elevated privileges (Run as Administrator)."
    exit
}

cls
Write-Host "STATUS:"
Write-Host " "
Write-Host "Script started at $(Get-Date)"

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Stop-ZabbixAgentService -ServiceName $ServiceName
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Install-Module PowerShellGet -Force -AllowClobber
Install-Module Microsoft.PowerShell.PSResourceGet -Repository PSGallery -Force -AllowClobber
#Ensure-Module -ModuleName "PowerShellGet"
#Ensure-Module -ModuleName "PackageManagement"
Ensure-PackageProvider -ProviderName "NuGet" -MinimumVersion $nuGetProviderMinVersion

#Downloading the correct ZABBIX version for the system architecture
if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
#Downloading the correct ZABBIX version for the system architecture
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://cdn.zabbix.com/zabbix/binaries/stable/7.2/$version/zabbix_agent-$version-windows-amd64-openssl.msi"  -OutFile "C:\Tools\ZabbixAgent-v$version.msi"
} else {
# Version for 32-bit architecture
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://cdn.zabbix.com/zabbix/binaries/stable/7.2/$version/zabbix_agent-$version-windows-i386-openssl.msi" -OutFile "C:\Tools\ZabbixAgent-v$version.msi"
}
#Install the downloaded version of ZABBIX for the appropriate system architecture
Start-Process -FilePath "C:\Tools\ZabbixAgent-v$version.msi" -ArgumentList "/qn SERVER=$ZabbixServer SERVERACTIVE=$ZabbixServerActive HOSTNAME=$env:computername ListenPort=$ListenPort EnablePath=$EnablePath" -Wait

############ Zabbix Agent Service #################
Stop-ZabbixAgentService -ServiceName $ServiceName

############ UPDATE ZABBIX CONFIG FILE #################
Start-Sleep -Seconds 5
Write-Host "Reconfiguring Zabbix Agent " -NoNewline

Get-ChildItem $AgentConfFile | Rename-Item -NewName {$_.BaseName + "_" + (Get-Date -F ddMMyyyy_HHmm) + $_.Extension}
Copy-Item -Path $templatePath -Destination "C:\Program Files\Zabbix Agent\zabbix_agentd.conf" -Force

Start-Sleep -Seconds 2
Write-Host "... " -NoNewline
Write-Host "DONE" -ForegroundColor Green

Start-Sleep -Seconds 2
Write-Host "Writing variables into Zabbix Agent config file " -NoNewline

$ConfigContent = Get-Content $AgentConfFile
$ConfigContent | ForEach-Object {
	if($_ -eq "HostInterface="){
		$ConfigContent[$ConfigContent.IndexOf($_)] += $HostInterface
	}
    
    if($_ -eq "Hostname="){
		$ConfigContent[$ConfigContent.IndexOf($_)] += $env:COMPUTERNAME
	}
}

if ($HostInterface -like '10.145.*' -and $Model -eq '3') {
    $ConfigContent | ForEach-Object {
	    if($_ -eq "Server="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "10.145.162.105"
	    }

        if($_ -eq "ServerActive="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "10.145.162.105"
	    }

        if($_ -eq "HostMetaData="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "Windows servers"
	    }
    }
} elseif ($HostInterface -like '10.30.*' -and $Model -eq '3') {
    $ConfigContent | ForEach-Object {
	    if($_ -eq "Server="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "10.30.8.4"
	    }

        if($_ -eq "ServerActive="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "10.30.8.4"
	    }

        if($_ -eq "HostMetaData="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "Windows servers"
	    }
    }
} else {
    $ConfigContent | ForEach-Object {
	    if($_ -eq "Server="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "10.145.162.105"
	    }

        if($_ -eq "ServerActive="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "10.145.162.105"
	    }

        if($_ -eq "HostMetaData="){
		    $ConfigContent[$ConfigContent.IndexOf($_)] += "Windows clients"
	    }
    }
}

Set-Content $AgentConfFile -Value $ConfigContent

Start-Sleep -Seconds 2
Write-Host "... " -NoNewline
Write-Host "DONE" -ForegroundColor Green

############ Zabbix Agent Service #################
Start-Sleep -Seconds 10
Start-ZabbixAgentService -ServiceName $ServiceName
Write-Host "Upgrade of Zabbix Agent completed, the PowerShell window will close in 10 seconds..." -ForegroundColor Green
Start-Sleep 10 
Stop-Process -Id $PID