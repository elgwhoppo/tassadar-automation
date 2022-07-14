 #      Script: InstallUpdatesAndRestart.ps1
#      Author: Gregory Strike, Modified by Dan Tonge
#     Website: www.GregoryStrike.com, www.techexplorer.co.uk
#        Date: 19-02-2010, 07-06-2015 DT - added warnings, modified reboot logic and added email report with status code lookup
#              17-06-2021 DT - added check for elevated privileges
#
# Information: This script was adapted from the WUA_SearchDownloadInstall.vbs VBScript from Microsoft.  It uses the
#              Microsoft.Update.Session COM object to query a WSUS server, find applicable updates, and install them.
#
#              InstallUpdatesAndRestart.ps1 is a little less verbose about what it is doing when compared to the original VBScript.  The
#              lines exist in the code below to show the same information as the original but are just commented out.
#
#
#              InstallUpdatesAndRestart.ps1 can automatically install applicable updates by passing a Y to the script.  The default
#              behaviour is to ask whether or not to install the new updates.
#
#              Syntax:  .\InstallUpdatesAndRestart.ps1 [Install] [Reboot]
#                       Where [Install] is optional and can be "Y", "Yes", "No" or "N"
#                       Whether or not to install the updates automatically.  If Null, the user will be prompted.
#
#                       Where [Reboot] is optional and can be "Y", "Yes", "No" or "N",  This 
#                       If updates require a reboot, whether or not to reboot automatically.  If Null, the user will
#                       be prompted.
#--------------------------------------------------------------------------------------------------------------------------------------

function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
        return $principal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )
    } catch {
        throw "Failed to determine if the current user has elevated privileges. The error was: '{0}'." -f $_
    }

    <#
        .SYNOPSIS
            Checks if the current Powershell instance is running with elevated privileges or not. Function by Andy Arismendi.
        .EXAMPLE
            PS C:\> Test-IsAdmin
        .OUTPUTS
            System.Boolean
                True if the current Powershell is elevated, false if not.
        .LINK
            https://stackoverflow.com/questions/9999963/test-admin-rights-within-powershell-script
    #>
}

# check script is running with admin rights
if (!(Test-IsAdmin)) {
    Write-Host "The current Windows PowerShell session is not running as Administrator. Start Windows PowerShell by using the Run as Administrator option, and then try running the script again." -Fore Red
    exit
} 

## include the SendEmail PowerShell script
."c:\scripts\powershell\Send-Email.ps1"

## build a list of email recipients
$EmailRecipients = @("user@yourdomain.co.uk","admin@yourdomain.co.uk")
$EmailBody = ""

$UpdateSession = New-Object -Com Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

$Install = [System.String]$Args[0]
$Reboot  = [System.String]$Args[1]

If ($Reboot.ToUpper() -eq "Y" -or $Reboot.ToUpper() -eq "YES"){
    Write-Host("")
    Write-Host("WARNING: this script will automatically restart this server if Windows updates") -Fore Red
    Write-Host("are found and installed.") -Fore Red
    Write-Host("")
    Write-Host("Press CTRL-C to cancel if you don't want this to happen") -Fore Red
} else {
    Write-Host("")
    Write-Host("This script will not restart if Windows updates are found and installed.") -Fore Red
    Write-Host("")
    Write-Host("You should manually resart this server manually if necessary.") -Fore Red
}

Write-Host("") 
Write-Host("Searching for applicable updates...") -Fore Green
 
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")
 
Write-Host("")
Write-Host("List of applicable items on the machine:") -Fore Green
$EmailBody = $EmailBody + "List of applicable items on the machine:"
For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    Write-Host( ($X + 1).ToString() + "`> " + $Update.Title)
    $EmailBody = $EmailBody + "`n" + ($X + 1).ToString() + "`> " + $Update.Title
}

If ($SearchResult.Updates.Count -eq 0) {
    Write-Host("") 
    Write-Host("There are no applicable updates.")
    Write-Host("") 
    Exit
}

#Write-Host("")
#Write-Host("Creating collection of updates to download:") -Fore Green
 
$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
 
For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    #Write-Host( ($X + 1).ToString() + "`> Adding: " + $Update.Title)
    $Null = $UpdatesToDownload.Add($Update)
}

Write-Host("")
Write-Host("Downloading Updates...")  -Fore Green
$EmailBody = $EmailBody + "`n`nDownloading updates"

$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$Null = $Downloader.Download()
 
#Write-Host("")
#Write-Host("List of Downloaded Updates...") -Fore Green
 
$UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
 
For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    If ($Update.IsDownloaded) {
        #Write-Host( ($X + 1).ToString() + "`> " + $Update.Title)
        $Null = $UpdatesToInstall.Add($Update)        
    }
}
 
If (!$Install){
    $Install = Read-Host("Would you like to install these updates now? (Y/N)")
}

## define a function to lookup windows update status codes
Function resResultDescription ($val)
{
    Switch ($val){
        0 {"Not Started"}
        1 {"In Progress"}      
        2 {"Succeeded"}         
        3 {"Succeeded With Errors"}  
        4 {"Failed"}
        5 {"Aborted"}
        default {"Unknown ($val)"}
     }
}

If ($Install.ToUpper() -eq "Y" -or $Install.ToUpper() -eq "YES"){
    Write-Host("")
    Write-Host("Installing Updates...") -Fore Green
    $EmailBody = $EmailBody + "`nInstalling updates"
 
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
 
    $InstallationResult = $Installer.Install()
 
    Write-Host("")
    Write-Host("List of Updates Installed with Results:") -Fore Green
    
    $EmailBody = $EmailBody + "`n`nInstallation results:"
 
    For ($X = 0; $X -lt $UpdatesToInstall.Count; $X++){
        $ResultDescription = resResultDescription($InstallationResult.GetUpdateResult($X).ResultCode)
        Write-Host($UpdatesToInstall.Item($X).Title + ": " +  $ResultDescription)
        $EmailBody = $EmailBody + "`n" + $ResultDescription  + ": " + $UpdatesToInstall.Item($X).Title
    }
 
    Write-Host("")
    Write-Host("Installation Result: " + $InstallationResult.ResultCode)
    Write-Host("    Reboot Required: " + $InstallationResult.RebootRequired)
    
    $ResultDescription2 = resResultDescription($InstallationResult.ResultCode)
    $EmailBody = $EmailBody + "`nOverall results: " + $ResultDescription2 + "`nRestart Required: " + $InstallationResult.RebootRequired
 
    If ($InstallationResult.RebootRequired -eq $True){
        If (!$Reboot){
            $Reboot = Read-Host("Would you like restart now? (Y/N)")
        }
 
        If ($Reboot.ToUpper() -eq "Y" -or $Reboot.ToUpper() -eq "YES"){
            $ErrorActionPreference = 'Stop'
            Write-Host("")
            Write-Host("Restarting...") -Fore Green
            $EmailBody = $EmailBody + "`n`nRestarting now..."
            Send-Email -EmailTo $EmailRecipients -EmailSubject "Restarting after Windows updates installed" -EmailBody $EmailBody
            $MyComputerName = [String]$env:computerName.ToLower()
            $OperatingSystemObject = Get-WmiObject Win32_OperatingSystem -Comp $MyComputerName -EnableAllPrivileges

            try {
                $OperatingSystemObject.reboot()

            } catch {
                Write-Host("Error - couldn't restart using that method, trying another...") -Fore Red
                try {
                    Restart-Computer -Force
                    } catch {
                        $e2 = $_.Exception
                        $EmailErrorBody = "Reboot failure: `n" + $e2
                        Send-Email -EmailTo $EmailRecipients -EmailSubject "Error while restarting" -EmailBody $EmailErrorBody
                        throw $e2
                    } finally {
                       # Send-Email -EmailTo $EmailRecipients -EmailSubject "Restarting after Windows updates installed" -EmailBody $EmailBody
                    }
            }  finally {
                       # Send-Email -EmailTo $EmailRecipients -EmailSubject "Restarting after Windows updates installed (2)" -EmailBody $EmailBody
            }
            
        } else {
            #reboot required, but not enabled using script parameters 
            $EmailBody = $EmailBody + "`n`nFinished."
            Send-Email -EmailTo $EmailRecipients -EmailSubject "Windows updates installed - manual restart needed ASAP" -EmailBody $EmailBody
        }
    }
    else {
        $EmailBody = $EmailBody + "`n`nFinished."
        Send-Email -EmailTo $EmailRecipients -EmailSubject "Windows updates installed - no restart needed" -EmailBody $EmailBody
    }
} 
