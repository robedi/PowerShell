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
    try {
        Start-Service -Name $ServiceName -ErrorAction Stop
        $maxWait = 30  # seconds
        $waited = 0

        do {
            Start-Sleep -Seconds 2
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            $waited += 2
            Write-Host "Waiting for service to start... ($waited sec)"
        } while ($service.Status -ne 'Running' -and $waited -lt $maxWait)

        if ($service.Status -eq 'Running') {
            Write-Host "Service $ServiceName is running."
        } else {
            throw "Service $ServiceName failed to start within timeout."
        }
    } catch {
        Write-Warning "Failed to start service $ServiceName. Attempting cleanup and reinstall."
        sc.exe delete "$ServiceName" | Out-Null
        Start-Sleep -Seconds 5
        if ($ServiceName -eq "Zabbix Agent") {
            Install-ZabbixAgent1
        } elseif ($ServiceName -eq "Zabbix Agent 2") {
            Install-ZabbixAgent2
        }
    }
}