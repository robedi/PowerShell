Set-ExecutionPolicy Bypass Process

$AllNICs = Get-VM | Get-VMNetworkAdapter | Where-Object {$_.MacAddress -ne "000000000000"}

if($AllNICs -ne $null) {
    (($AllNICs).GetEnumerator() | Group-Object MacAddress | ? {$_.Count -gt 1}).Group | Ft MacAddress,Name,VMName -GroupBy MacAddress -AutoSize
    }
Else {
    Write-Host "No duplicated MAC addresses where found on your Hyper-V host"
    }