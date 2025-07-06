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
            Update-Module -Name $ModuleName -Force
        } else {
            Write-Output "Module $ModuleName is up-to-date (version $installedVersion)."
        }
    }
}