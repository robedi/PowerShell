

<#
.SYNOPSIS
    Create a new function
.DESCRIPTION
    This function creates a new function that wraps the selected text inside
    the Process section of the body of the function.
.PARAMETER SelectedText
    Currently selected code that will become a function
.PARAMETER InstallMenu
    Specifies if you want to install this as a PSIE add-on menu
.PARAMETER FunctionName
    This is the name of the new function.
.EXAMPLE
    New-Function -FunctionName "New-ImprovedFunction"
            
    Description
    -----------
    This example shows calling the function with the FunctionName parameter
.EXAMPLE
    New-Function -InstallMenu $true
            
    Description
    -----------
    Installs the function as a menu item.
.NOTES
    FunctionName    : New-Function
    Created by      : Jeff Patton
    Date Coded      : 09/13/2011 13:37:24
    Modified by     : Dejan Mladenovic
    Date Modified   : 03/09/2019 05:12:10
    More info       : https://improvescripting.com/
.LINK
    https://improvescripting.com/how-to-write-advanced-functions-or-cmdlets-with-powershell-fast/
    https://gallery.technet.microsoft.com/scriptcenter/PSISELibraryps1-ec442972
#>
Function New-Function  
{  
    [CmdletBinding()]
    Param
        (
        $SelectedText = $psISE.CurrentFile.Editor.SelectedText,
        $InstallMenu,
        $FunctionName
        )
    Begin
    {

        $TemplateFunction = @(
        "<#`r`n"
        "   .SYNOPSIS`r`n"
        "   .DESCRIPTION`r`n"
        "   .PARAMETER`r`n"
        "   .EXAMPLE`r`n"
        "   .INPUTS`r`n"
        "   .OUTPUTS`r`n"
        "   .NOTES`r`n"
        "       FunctionName : $FunctionName`r`n"
        "       Created by   : $($env:username)`r`n"
        "       Date Coded   : $(Get-Date)`r`n"
        "   .LINK`r`n"
        "       https://github.com/RoBeDi/PowerShell/`r`n"
        "#>`r`n"       
        "`r`n"       
        "Function $FunctionName`r`n"
        "{`r`n"
        "[CmdletBinding()]`r`n"
        "Param`r`n"
        "    (`r`n"
        "    )`r`n"
        "Begin`r`n"
        "{`r`n"
        "    }`r`n"
        "Process`r`n"
        "{`r`n"
        "$($SelectedText)`r`n"
        "    }`r`n"
        "End`r`n"
        "{`r`n"
        "    }`r`n"
        "}`r`n"       
        "`r`n" 
        "#region Execution examples`r`n"
        "#endregion`r`n")
        if ($InstallMenu)
        {
            Write-Verbose "Try to install the menu item, and error out if there's an issue."
            try
            {
                $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("New function",{New-Function},"Ctrl+Alt+S") | Out-Null
                }
            catch
            {
                Return $Error[0].Exception
                }
            }

        }
    Process
    {
        if (!$InstallMenu)
        {
            Write-Verbose "Don't create a function if we're installing the menu"
            try
            {
                Write-Verbose "Create a new empty function, return an error if there's an issue."
                $psISE.CurrentFile.Editor.InsertText($TemplateFunction)
                }
            catch
            {
                Return $Error[0].Exception
                }
            }
        }
    End
    {
        }
    }
#region Execution examples
New-Function -InstallMenu $true
#endregion
