<# 
.SYNOPSIS 
Reset-WindowsUpdate.ps1 - Resets the Windows Update components for Windows 10 and 11 

.DESCRIPTION  
This script will reset all of the Windows Updates components to DEFAULT SETTINGS for Windows 10 and Windows 11.

.OUTPUTS 
Results are printed to the console. Future releases will support outputting to a log file.  

.NOTES 
Written by: Ryan Nemeth 
Updated by: Roland van 't Kruijs

Change Log 
V1.00, 05/21/2015 - Initial version 
V1.10, 09/22/2016 - Fixed bug with call to sc.exe 
V1.20, 11/13/2017 - Fixed environment variables 
V2.00, 09/30/2024 - Updated for compatibility with Windows 10 and 11 
#> 

cls 

# Check if the script is running in elevated mode (as Administrator)
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires elevated privileges (Run as Administrator)."
    exit
}

$arch = Get-WMIObject -Class Win32_Processor -ComputerName LocalHost | Select-Object AddressWidth 

Write-Host "1. Stopping Windows Update Services..." 
Stop-Service -Name BITS -Force
Stop-Service -Name wuauserv -Force
Stop-Service -Name appidsvc -Force
Stop-Service -Name cryptsvc -Force

Write-Host "2. Remove QMGR Data file..." 
Remove-Item "$env:ProgramData\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue 

Write-Host "3. Renaming the Software Distribution and CatRoot Folder..." 
if (Test-Path "$env:SystemRoot\SoftwareDistribution\DataStore") {
    Rename-Item "$env:SystemRoot\SoftwareDistribution\DataStore" "$env:SystemRoot\SoftwareDistribution\DataStore.bak" -ErrorAction SilentlyContinue
}

if (Test-Path "$env:SystemRoot\SoftwareDistribution\Download") {
    Rename-Item "$env:SystemRoot\SoftwareDistribution\Download" "$env:SystemRoot\SoftwareDistribution\Download.bak" -ErrorAction SilentlyContinue 
}

if (Test-Path "$env:SystemRoot\System32\Catroot2") {
    Rename-Item "$env:SystemRoot\System32\Catroot2" "$env:SystemRoot\System32\Catroot2.bak" -ErrorAction SilentlyContinue
} 

Write-Host "4. Removing old Windows Update log..."
if (Test-Path "$env:SystemRoot\WindowsUpdate.log") {
    Remove-Item "$env:SystemRoot\WindowsUpdate.log" -ErrorAction SilentlyContinue
} 

Write-Host "5. Resetting the Windows Update Services to default settings..." 
sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)
sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)

Write-Host "6. Registering some DLLs..." 
$DLLs = @(
    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll", "vbscript.dll",
    "scrrun.dll", "msxml.dll", "msxml3.dll", "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll",
    "dssenh.dll", "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll", "oleaut32.dll",
    "ole32.dll", "shell32.dll", "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll",
    "wups2.dll", "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll"
)

foreach ($dll in $DLLs) {
    regsvr32.exe /s $dll
}

Write-Host "7) Removing WSUS client settings..." 
REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f 
REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f 
REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f 

Write-Host "8) Resetting the WinSock..." 
netsh winsock reset 
netsh winhttp reset proxy 

Write-Host "9) Delete all BITS jobs..." 
Get-BitsTransfer | Remove-BitsTransfer 

Write-Host "10) Installing the Windows Update Agent (if needed)..." 
if ($arch -eq 64) { 
    wusa.exe "Windows10.0-KB5003173-x64.msu" /quiet /norestart 
} 
else { 
    wusa.exe "Windows10.0-KB5003173-x86.msu" /quiet /norestart 
}

Write-Host "11) Starting Windows Update Services..." 
Start-Service -Name BITS 
Start-Service -Name wuauserv 
Start-Service -Name appidsvc 
Start-Service -Name cryptsvc 

Write-Host "12) Forcing discovery..." 
usoclient.exe StartScan

Write-Host "Process complete. Please reboot your computer."
Restart-Computer -Force
