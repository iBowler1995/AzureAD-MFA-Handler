<#
    NOTES
	===========================================================================
	 Script Name: Azure MFA Handler
	 Created on:   	12/1/2021
	 Created by:   	iBowler1995
	 Filename: MFAHandler.ps1
	===========================================================================
	.DESCRIPTION
		This script is used to clean files and folders older than x days in a specified directory
	===========================================================================
	IMPORTANT:
	===========================================================================
	This script is provided 'as is' without any warranty. Any issues stemming 
	from use is on the user.
    ===========================================================================
    .PARAMETER UPN
    This parameter is a string and is required - specifies the target user
    .PARAMETER Enable
    This parameter is a switch - specifies that you want to enable MFA 
    .PARAMETER Disable
    This parameter is a switch - specifies that you want to disable MFA
    .PARAMETER Bulk
    This parameter is a switch - specify this if you have a bulk action to do
    .PARAMETER FilePath
    This parameter is a switch - required if using Bulk switch. Specifies path to txt or csv file contiaining the UPNs

    .EXAMPLES
    MFAHandler.ps1 -UPN bsmith@example.com <--- This will attempt to display MFA status for bsmith@example.com

    MFAHAndler.ps1 -UPN bsmith@example.com -Enable <--- This will attempt to enable MFA for bsmith@example.com

    MFAHAndler.ps1 -UPN bsmith@example.com -Disbale <--- This will attempt to disable MFA for bsmith@example.com

    MFAHAndler.ps1 
    #>
[cmdletbinding()]
param (
    [Parameter(Mandatory=$False)]
    [String]$UPN,
    [Parameter(Mandatory=$False)]
    [Switch]$Enable,
    [Parameter(Mandatory=$False)]
    [Switch]$Disable,
    [Parameter(Mandatory=$False)]
    [Switch]$Bulk,
    [Parameter(Mandatory=$False)]
    [String]$FilePath
)

#Ensures proper module is installed
if ((Get-InstalledModule `
        -Name "MSOnline" `
        -ErrorAction SilentlyContinue) -eq $null){
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201
            Install-Module -Name MSOnline -Repository PSGallery -Force
        } 
#Variable for auto logon        
$CredsExist = '.\cred.xml'        

#Auto logon if credentials saved, else prompt for credentials
If (Test-Path $CredsExist -PathType leaf){
            $RetrieveCredentials = Import-Clixml -Path '.\cred.xml'
            Connect-MsolService -Credential $RetrieveCredentials
        }
else{
            $SaveCredentials = Get-Credential
            $SaveCredentials | Export-Clixml -Path '.\cred.xml' -Force
            $RetrieveCredentials = Import-Clixml -Path '.\cred.xml'
            Connect-MsolService -Credential $RetrieveCredentials
        }  
    
#Looking up user
$MsolUser = Get-MsolUser -UserPrincipalName $UPN -ErrorAction Stop
#This creates a custom property that checks whether strong authentication is enforced            
$MFAStatus = [PSCustomObject]@{
MFAEnabled  = if ($MsolUser.StrongAuthenticationMethods) { $true } else { $false }  
}

If ($Enable -and !$Bulk){
    #Creates a new PSObject to obtain MFA state and places into an array
    $sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
    $sa.RelyingParty = "*"
    $sa.State = "Enabled"
    $sar = @($sa)
     
    Try
    {
        #Attempts to set MFA to enabled
        Set-MsolUser -UserPrincipalName $UPN -StrongAuthenticationRequirements $sar
    }
    catch
    {
        #Catch for errors
        Write-Host "MFA Enable failed. Reason: $($Error[0].Exception.InnerException)" $ForegroundColor Yellow
    }
    #Confirms action was successful, warns if not
    if ($MFAStatus -eq $False) {
        Write-Host "MFA still disabled. Please try again or check the portal" $ForegroundColor Yellow
    }
    else{
        Write-Host "MFA successfully enabled." $ForegroundColor Green
    }
}
    
elseif ($Disable -and !$Bulk){        
    Try {
        #Attempts to set MFA to disabled
        Set-MsolUser -UserPrincipalName $UPN -StrongAuthenticationRequirements @()
    }
    Catch {
        #Catch for errors
        Write-Host "MFA Disable failed. Reason: $($Error[0].Exception.InnerException)" $ForegroundColor Yellow
    }
    #Confirms action was successful, warns if not
    If ($MFAStatus -eq $True) {
        Write-Host "MFA still enabled. Please try again or check the portal." $ForegroundColor Yellow
    }
    else{
        Write-Host "MFA successfully disabled." $ForegroundColor Green
    }
}

#Catch in case user forgets to specify filepath
elseif ($Bulk -and $FilePath -eq $null) {
    Write-Host "Bulk switch used but filepath not specified. Please specify filepath or remove Bulk switch and try again." $ForegroundColor Yellow
} 
elseif($Bulk -and $Enable){
    $users = Get-Content $FilePath
    foreach ($User in $Users) {
        $sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
        $sa.RelyingParty = "*"
        $sa.State = "Enabled"
        $sar = @($sa)
     
        Try{
            #Attempts to set MFA to enabled
            Set-MsolUser -UserPrincipalName $UPN -StrongAuthenticationRequirements $sar
        }
        catch{
            #Catch for errors
            Write-Host "MFA Enable failed. Reason: $($Error[0].Exception.InnerException)" $ForegroundColor Yellow
        }
        #Confirms action was successful, warns if not
        if ($MFAStatus -eq $False) {
            Write-Host "MFA still disabled. Please try again or check the portal" $ForegroundColor Yellow
        }
        else{
            Write-Host "MFA successfully enabled for $($MsolUser.DisplayName)." $ForegroundColor Green
        }
    }
}

elseif($Bulk -and $Disable){
    $Users = Get-Content $FilePath
    foreach ($User in $Users){
        Try {
            #Attempts to set MFA to disabled
            Set-MsolUser -UserPrincipalName $UPN -StrongAuthenticationRequirements @()
        }
        Catch {
            #Catch for errors
            Write-Host "MFA Disable failed. Reason: $($Error[0].Exception.InnerException)" $ForegroundColor Yellow
        }
        #Confirms action was successful, warns if not
        If ($MFAStatus -eq $True) {
            Write-Host "MFA still enabled. Please try again or check the portal." $ForegroundColor Yellow
        }
        else{
            Write-Host "MFA successfully disabled." $ForegroundColor Green
        }
    }
}

else {
    If ($MFAStatus -eq $True){
        Write-Host "User $($MsolUser.DisplayName) MFA status: Enabled."
    }
    elseif($MFAStatus -eq $False){
        Write-Host "User $($MsolUser.DisplayName) MFA status: Disabled."
    }
    else {
        Write-Host "Unable to determine MFA status for $($MsolUser.DisplayName)."
    }
 }
    