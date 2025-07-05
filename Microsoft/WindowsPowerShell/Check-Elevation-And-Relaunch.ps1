function Ensure-Elevated {
    <#
    .SYNOPSIS
        Ensures the current PowerShell session is running with administrative privileges.
        If not, relaunches the script with elevated permissions.

    .DESCRIPTION
        This function checks whether the current PowerShell session has administrator privileges.
        If it does not, it attempts to relaunch the calling script with elevated permissions (Run as Administrator).
        Typically used at the start of scripts that require elevated access to avoid permission issues.

    .NOTES
        The function exits the current session if elevation is triggered.
        Designed for script use, not interactive console commands.

    .EXAMPLE
        Ensure-Elevated
    #>

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "This script requires elevated privileges (Run as Administrator). Relaunching in elevated PowerShell console..."

        $script = $MyInvocation.MyCommand.Path

        if (-not $script) {
            Write-Error "Unable to determine script path. This function must be called from a script file."
            exit 1
        }

        # Choose PowerShell ISE or Console depending on environment
        $hostApp = if ($psISE) { "powershell_ise.exe" } else { "powershell.exe" }

        Start-Process $hostApp -Verb RunAs -ArgumentList "-File `"$script`""
        exit
    }
}
