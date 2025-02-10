<#
    .SYNOPSIS
        Inserts a full comment block
    .DESCRIPTION
        This function inserts a full comment block that is formatted the
        way I format all my comment blocks.
    .PARAMETER InstallMenu
        Specifies if you want to install this as a PSIE add-on menu
    .EXAMPLE
        New-CommentBlock -InstallMenu $true
            
        Description
        -----------
        Installs the function as a menu item.
    .NOTES
        FunctionName    : New-CommentBlock
        Created by      : Jeff Patton
        Date Coded      : 09/13/2011 13:37:24
        Modified by     : Dejan Mladenovic
        Date Modified   : 02/09/2019 01:19:10
        More info       : https://improvescripting.com/
    .LINK
        https://improvescripting.com/how-to-write-powershell-functions-or-cmdlets-help-fast/
        https://gallery.technet.microsoft.com/scriptcenter/PSISELibraryps1-ec442972
#>
Function New-CommentBlock
{
    [CmdletBinding()]
    Param
        (
        $InstallMenu
        )
    Begin
    {
        
        $CommentBlock = @(
            "<#`r`n"
            "   .SYNOPSIS`r`n"
            "   .DESCRIPTION`r`n"
            "   .PARAMETER`r`n"
            "   .EXAMPLE`r`n"
            "   .INPUTS`r`n"
            "   .OUTPUTS`r`n"
            "   .NOTES`r`n"
            "       FunctionName : `r`n"
            "       Created by   : $($env:username)`r`n"
            "       Date Coded   : $(Get-Date)`r`n"
            "   .LINK`r`n"
            "       https://github.com/RoBeDi/PowerShell/`r`n"
            "#>`r`n")
        if ($InstallMenu)
        {
            Write-Verbose "Try to install the menu item, and error out if there's an issue."
            try
            {
                $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("Insert comment block",{New-CommentBlock},"Ctrl+Alt+C") | Out-Null
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
            Write-Verbose "Don't insert a comment if we're installing the menu"
            try
            {
                Write-Verbose "Create a new comment block, return an error if there's an issue."
                $psISE.CurrentFile.Editor.InsertText($CommentBlock)
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
New-CommentBlock -InstallMenu $true
#endregion