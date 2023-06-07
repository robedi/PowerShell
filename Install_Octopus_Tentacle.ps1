clear

<#
Set-ExecutionPolicy -ExecutionPolicy ByPass
#>


$serverThumbprint = "<your Thumbprint>"
$serverUri = "http://your URL"
$tentacleInstallApiKey = "API-<your APIKey>"
$appfolder = "C:\<foldername>"
$role = Read-Host -Prompt 'Provide the Role ID (all caps)'
$environment = Read-Host -Prompt 'Provide the Environment ID (all caps)'
$path = "C:\Tools"
$reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

clear

function Tentacle-Configure([string]$arguments)
{
    #Write-Output "Configuring Tentacle with $arguments"

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "C:\Program Files\Octopus Deploy\Tentacle\Tentacle.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.CreateNoWindow = $true; 
    $pinfo.UseShellExecute = $false;
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    
    Write-Host $stdout -ForegroundColor Yellow
    Write-Host $stderr -ForegroundColor Red
    
    if ($p.ExitCode -ne 0) {
        Write-Host "Exit code: " + $p.ExitCode
        throw "Configuration failed"
    }
}

function Get-ExternalIP {
    return (Invoke-WebRequest http://myexternalip.com/raw).Content.TrimEnd()
}


Write-Host "[OCTOPUS TENTACLE INSTALLATION]"

If(!(Test-Path $path)){
    New-Item -ItemType Directory -Force -Path $path
}

Set-ItemProperty -Path $reg -Name ProxyServer -Value "<proxyserver>:<port>"
Set-ItemProperty -path $reg -Name ProxyOverride -Value "<local>*.domain.com"
Set-ItemProperty -Path $reg -Name ProxyEnable -Value 1

Write-Host "Downloading latest Octopus Tentacle MSI..." -ForegroundColor Yellow

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$downloader = new-object System.Net.WebClient
$downloader.DownloadFile("https://octopus.com/downloads/latest/OctopusTentacle64", "$path\Tentacle.msi")

Write-Host "Installing Octopus Tentacle..." -ForegroundColor Yellow
$msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $path\Tentacle.msi /quiet" -Wait -Passthru).ExitCode
if ($msiExitCode -ne 0) {
    Write-Host "Tentacle MSI installer returned exit code $msiExitCode" -ForegroundColor Red
    throw "Installation aborted"
}

Write-Host "Configuring Octopus Tentacle..." -ForegroundColor Yellow

Tentacle-Configure "create-instance --instance `"Tentacle`" --config `"C:\Octopus\Tentacle.config`" --console"
Tentacle-Configure "new-certificate --instance `"Tentacle`" --if-blank --console"
Tentacle-Configure "configure --instance `"Tentacle`" --reset-trust --console"
Tentacle-Configure "configure --instance `"Tentacle`" --home `"C:\Octopus`" --app `"$appfolder`" --port `"10933`" --console"
Tentacle-Configure "configure --instance `"Tentacle`" --trust `"$serverThumbprint`" --console"
Tentacle-Configure "register-with --instance `"Tentacle`" --server `"$serverUri`" --apiKey=`"$tentacleInstallApiKey`" --role `"$role`" --environment `"$environment`" --comms-style TentaclePassive --force --console"
Tentacle-Configure "service --instance `"Tentacle`" --restart"
Tentacle-Configure "service --instance `"Tentacle`" --install --start --console"
Tentacle-Configure "watchdog --create --instances *"

Write-Host "Cleaning up installation files and settings..." -ForegroundColor Yellow

Remove-ItemProperty -Path $reg -Name ProxyServer
Remove-ItemProperty -Path $reg -Name ProxyOverride
Set-ItemProperty -Path $reg -Name ProxyEnable -Value 0
Remove-Item "$path\Tentacle.msi"
Remove-Item $PSCommandPath

Write-Host "Installation Octopus Tentacle completed..." -ForegroundColor Green