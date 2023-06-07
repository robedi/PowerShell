#create array with users from multiple OU and add filter "user AD object enabled".
$ouArray += Get-ADUser -SearchBase "OU=<your OU name>,OU=<your OU name>,OU=<your OU name>,DC=<your domain name>,DC=<your domain name>,DC=<your domain name>" -Filter {enabled -eq $true} 
$ouArray += Get-ADUser -SearchBase "OU=<your OU name>,OU=<your OU name>,OU=<your OU name>,DC=<your domain name>,DC=<your domain name>,DC=<your domain name>" -Filter {enabled -eq $true}

#declare AD Group for search
$group = "<your group name>"

#declare AD Group for second task - add membership
$group2 = Get-ADGroup "CN=<your group name>,OU=<your OU name>,OU=<your OU name>,DC=<your domain name>,DC=<your domain name>,DC=<your domain name>"

#check membership
$members = Get-ADGroupMember -Identity $group -Recursive | Select -ExpandProperty sAMAccountName
$ouArray | ForEach-Object {$user = $_.sAMAccountName
If ($members -contains $user) {
} Else {

    #if users doesn't exist in AD Group - add them to AD Group

    #also you may test this part with next string
    #Write-host "$user not exist in group"

    Add-ADGroupMember $group2 –Member $user
    }
}