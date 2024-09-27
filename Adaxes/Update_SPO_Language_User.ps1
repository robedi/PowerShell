[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.UserProfiles")

$collation = "25"
$LanguageID01 = "1030" # Danish
$LanguageID02 = "1031" # German
$LanguageID03 = "1033" # English
$LanguageID04 = "1043" # Dutch
$LanguageID05 = "1046" # Portuguese (Brazil)
$LanguageID06 = "1049" # Russian
$LanguageID07 = "1053" # Swedish
$LanguageID08 = "1058" # Ukrainian
$LanguageID09 = "2070" # Portuguese (Portugal)

$Locale = "1033"

$SiteURL = "https://contosocom-admin.sharepoint.com"

# Get access token from Azure AD Connector for SharePoint Online
$spoToken = $Context.CloudServices.GetAzureAuthAccessToken("https://contosocom-admin.sharepoint.com")

# Authenticate using the token with Connect-SPOService
Connect-SPOService -Url $SiteURL -AccessToken $spoToken

$username = $Context.TargetObject.Get("sAMAccountName")
$Upn = $username + '@contoso.com'
$ODUrl = "https://contosocom-my.sharepoint.com/Personal/"
$ODriveFullUrl = $ODUrl +  $Upn.Replace("@","_").replace('.','_') 

# Adding Admin access to user OneDrive
Set-SPOUser -Site $ODriveFullUrl -LoginName $Upn -IsSiteCollectionAdmin $true | Out-Null 

# Create SharePoint ClientContext using the token
$spocreds = New-Object Microsoft.SharePoint.Client.ClientContext($ODriveFullUrl)
$spocreds.ExecutingWebRequest += { 
    param($sender, $e)
    $e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + $spoToken)
}
$spocreds.ExecuteQuery()
$spocreds.Web.RegionalSettings.LocaleId = $Locale
$spocreds.Web.RegionalSettings.Collation = $collation                  
$spocreds.Web.IsMultilingual = $true
$spocreds.Web.AddSupportedUILanguage($LanguageID01)
$spocreds.Web.AddSupportedUILanguage($LanguageID02)
$spocreds.Web.AddSupportedUILanguage($LanguageID03)
$spocreds.Web.AddSupportedUILanguage($LanguageID04)
$spocreds.Web.AddSupportedUILanguage($LanguageID05)
$spocreds.Web.AddSupportedUILanguage($LanguageID06)
$spocreds.Web.AddSupportedUILanguage($LanguageID07)
$spocreds.Web.AddSupportedUILanguage($LanguageID08)
$spocreds.Web.AddSupportedUILanguage($LanguageID09)
$spocreds.Web.Update()
$spocreds.ExecuteQuery()

# Removing Admin access from User OneDrive
Set-SPOUser -Site $ODriveFullUrl -LoginName $Upn -IsSiteCollectionAdmin $false | Out-Null