#Usage:
#Get-ComputerVersionList -SearchBase $Searchbase -CSVPath $CSVPath

function Get-ComputersVersionList {

    param (
        [Parameter(Mandatory=$true)]
        [string]$SearchBase,
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )

    Get-ADComputer -SearchBase $SearchBase -Filter * -Properties DNSHostname, Description, operatingSystemVersion,LastLogonTimeStamp |
    Select-Object @{Name = 'ComputerName'; Expression = { $_.DNSHostname } }, Description,
    @{Name = 'OSVersion'; Expression = { $_.operatingSystemVersion } },
    @{Name = 'LastLogon'; Expression = { [datetime]::FromFileTime($_.lastLogonTimestamp) } } |
    Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "A CSV file has been created at ""$csvPath""." -ForegroundColor Green   
}

#Example with multiple countries

$countries = ("CA","BR","US")

foreach($country in $countries){

    $searchbase = "OU=Computers,OU=$country,DC=Contoso,DC=com"
    $CsvPath = "C:\temp\$($Country)computersList.csv"
    Get-ComputersVersionList -SearchBase $searchbase -CsvPath $CsvPath -Verbose
}