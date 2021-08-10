<#
    purpose: This will install WVD Admin and register the service principal for management
    run this on: a session host (aka desktop)
    by bfrank
    reference: https://blog.itprocloud.de/Windows-Virtual-Desktop-Admin/
#>

param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string] $AzureTenantId,

    [Parameter(Mandatory = $True, Position = 2)]
    [string] $ServicePrincipalId,

    [Parameter(Mandatory = $True, Position = 3)]
    [string] $ServicePrincipalKey
)
#this will be our temp folder - need it for download / logging
$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force }

#write a log file with the same name of the script
Start-Transcript "$tmpDir\$($SCRIPT:MyInvocation.MyCommand).log" -Force -Append

$URI = "https://blog.itprocloud.de/assets/files/WVDAdmin.msi"
$fileName = $([System.Uri]::new($URI).Segments | Select-Object -Last 1)
$destinationPath = "$tmpDir\{0}" -f $fileName

if (!(Test-Path $destinationPath)) {
    "downloading wvdadmin"
    #Invoke-WebRequest -Uri "https://aka.ms/fslogix_download" -OutFile $destinationPath -verbose
    #Start-BitsTransfer $URI $destinationPath -Priority High -RetryInterval 60 -Verbose -TransferType Download
    $client = new-object System.Net.WebClient
    $client.DownloadFile($URI,$destinationPath)
    $client.Dispose()
    #Expand-Archive $destinationPath -DestinationPath $tempPath -Force -verbose
}

#installing wvdadmin
Write-Output "installing wvdadmin"
Start-Process -FilePath "msiexec" -ArgumentList "/a $destinationPath /passive /lxv* c:\temp\$fileName.log AdminEulaForm_Property=NO TARGETDIR=""c:\Program Files\ITProCloud.de\WVDAdmin\""" -Wait

#create desktop shortcut
$TargetFile = "$env:ProgramFiles\ITProCloud.de\WVDAdmin\WVDAdmin.exe"
$ShortcutFile = "$env:Public\Desktop\WVDAdmin.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

<# no longer placing wvd service principal connection properties cleartext on desktop
$details = @"
'AzureAd Tenant Id' = $AzureTenantId
'Service Principal Id' = $ServicePrincipalId
'Service Principal Key' = $ServicePrincipalKey
"@

$details | Out-File -FilePath "$env:Public\Desktop\my WVDAdmin Connection Details.txt"
#>

#save registry file for user merge onto desktop
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Core

$data = [System.Text.Encoding]::Unicode.GetBytes($ServicePrincipalKey)
[byte[]]$encrypted = [System.Security.Cryptography.ProtectedData]::Protect($data,$null,[System.Security.Cryptography.DataProtectionScope]::LocalMachine)
$toreg = [System.Convert]::ToBase64String($encrypted);
$toreg

$regFile = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\ITProCloud]

[HKEY_CURRENT_USER\Software\ITProCloud\WVDAdmin]
"AzureAd Tenant Id"="$AzureTenantId"
"Service Principal Id"="$ServicePrincipalId"
"AzureAd Tenant Friendly Name"=""
"FeatureSet"=dword:00000002
"Service Principal Key"="$toreg"

[HKEY_CURRENT_USER\Software\ITProCloud\WVDAdmin\Rollout]

[HKEY_CURRENT_USER\Software\ITProCloud\WVDAdmin\Rollout\Default]
"@

$regFile | Out-File -FilePath "$env:Public\Desktop\Merge WVDAdmin azure connection details.reg"

Stop-Transcript