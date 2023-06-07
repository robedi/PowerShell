cls
#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$ServiceName = 'Zabbix Agent'
$arrService = Get-Service -Name $ServiceName
$currentIPAddress = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.status -ne "Disconnected"}).IPv4Address.IPAddress

write-host "Reconfiguring Zabbix Agent to Zabbix Proxy... " -NoNewline
$content = Get-Content -Path 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf'
$newContent = $content -replace '1.2.3.4', '4.3.2.1'
$newContent | Set-Content -Path 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf'
Start-Sleep -seconds 5
write-host "COMPLETED" -ForegroundColor Green
write-host "Checking/Adjusting current IP Address... " -NoNewline

# Loop through each line in the file content
for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i]

    # Check if the line starts with "HostInterface="
    if ($line -like "HostInterface=*") {
        $splitLine = $line -split "="

        # Extract the IP Address from the line
        $fileIPAddress = $splitLine[1]

        # Compare the IP Addresses
        if ($currentIPAddress -ne $fileIPAddress) {
            # IP Addresses are different
            # Replace the IP Address in the line
            $newLine = "HostInterface=$currentIPAddress"

            # Replace the line in the file content
            $newContent[$i] = $newLine
        }
    }
}

$newContent | Set-Content -Path 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf'
Start-Sleep -seconds 5
write-host "COMPLETED" -ForegroundColor Green

write-host "Service state of" $ServiceName "is currently: " -NoNewline

if ($arrService.Status -eq 'Running') {
    write-host $arrService.status -ForegroundColor Green
}

if ($arrService.Status -eq 'Stopped') {
    write-host $arrService.status -ForegroundColor Red
}

if ($arrService.Status -eq 'Running') {
    write-host 'Restarting' $ServiceName
    Restart-Service $ServiceName
} else {
    write-host 'Starting' $ServiceName
    Start-Service $ServiceName
}

Start-Sleep -seconds 10
$arrService.Refresh()

if ($arrService.Status -eq 'Running') {
    Write-Host 'Service is now Running'
}

write-host "Service state of" $ServiceName "is currently: " -NoNewline

if ($arrService.Status -eq 'Running') {
    write-host $arrService.status -ForegroundColor Green
}

if ($arrService.Status -eq 'Stopped') {
    write-host $arrService.status -ForegroundColor Red
}

if ($arrService.Status -ne 'Running') {
    write-host 'Starting' $ServiceName
    Start-Service $ServiceName
    $arrService.Refresh()

    write-host "Service state of" $ServiceName "is currently: " -NoNewline

    if ($arrService.Status -eq 'Running') {
        write-host $arrService.status -ForegroundColor Green
    }

    if ($arrService.Status -eq 'Stopped') {
        write-host $arrService.status -ForegroundColor Red
    }
}