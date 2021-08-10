# Software install Script
#
# Applications to install:
#
# Foxit Reader Enterprise Packaging (requires registration)
# https://kb.foxitsoftware.com/hc/en-us/articles/360040658811-Where-to-download-Foxit-Reader-with-Enterprise-Packaging-MSI-
# 
# Notepad++
# https://notepad-plus-plus.org/downloads/v7.8.8/
# See comments on creating a custom setting to disable auto update message
# https://community.notepad-plus-plus.org/post/38160

Start-Transcript -Path "c:\temp\install.ps1.log" -Force -Append
$ErrorActionPreference = "Continue"

#region Start Language Pack download
$ProgressPreference = 'SilentlyContinue'
$tmpDir = "D:\"
$myjobs = @() 

$LPdownloads = @{
    'LanguagePack' = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
    'FODPack'      = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
    'InboxApps'    = "https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso"
    #'ExperiencePack'= "https://software-download.microsoft.com/download/sg/LanguageExperiencePack.2105C.iso" #is part of the Language pack
}

Write-Output "Starting download jobs $(Get-Date)"
foreach ($download in $LPdownloads.GetEnumerator()) {
    $downloadPath = $tmpDir + "\$(Split-Path $($download.Value) -Leaf)"
    if (!(Test-Path $downloadPath )) {
        #download if not there
        $myjobs += Start-Job -ArgumentList $($download.Value), $downloadPath -Name "download" -ScriptBlock {
            param([string] $downloadURI,
                [string]$downloadPath
            )
            #Invoke-WebRequest -Uri $download -OutFile $downloadPath # is 10 slower than the webclient
            $wc = New-Object net.webclient
            $wc.Downloadfile( $downloadURI, $downloadPath)
        } 
    }
}

do {
    Start-Sleep 15
    $running = @($myjobs | Where-Object { ($_.State -eq 'Running') })
    $myjobs | Group-Object State | Select-Object count, name
    write-output "-----------------"
}
while ($running.count -gt 0)

Write-Output "Finished downloads $(Get-Date)"
#endregion

#region Foxit Reader
Write-Output "Installing Foxit Reader"
try {
    Start-Process -filepath msiexec.exe -Wait -ErrorAction Stop -ArgumentList '/i', 'c:\temp\software\FoxitReader101_enu_Setup.msi', '/quiet', 'ADDLOCAL="FX_PDFVIEWER"'
    if (Test-Path "C:\Program Files (x86)\Foxit Software\Foxit Reader\FoxitReader.exe") {
        Write-Output "Foxit Reader has been installed"
    }
    else {
        Write-Output "Error locating the Foxit Reader executable"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error installing Foxit Reader: $ErrorMessage"
}
#endregion

#region Notepad++
Write-Output "Installing notepadd++"
try {
    Start-Process -filepath 'c:\temp\software\npp.8.0.Installer.x64.exe' -Wait -ErrorAction Stop -ArgumentList '/S'
    Copy-Item 'C:\temp\software\config.model.xml' 'C:\Program Files\Notepad++'
    Rename-Item 'C:\Program Files\Notepad++\updater' 'C:\Program Files\Notepad++\updaterOld'
    if (Test-Path "C:\Program Files\Notepad++\notepad++.exe") {
        Write-Output "Notepad++ has been installed"
    }
    else {
        Write-Output "Error locating the Notepad++ executable"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error installing Notepad++: $ErrorMessage"
}
#endregion

#region vscode
Write-Output "Installing vscode"
try {
    Start-Process -filepath 'c:\temp\software\VSCodeSetup-x64-1.57.0.exe' -Wait -ErrorAction Stop -ArgumentList '/verysilent /norestart /closeapplications /mergetasks=!runcode /log=c:\temp\vscode.install.log'
    if (Test-Path "C:\Program Files\Microsoft VS Code\Code.exe") {
        Write-Output "VSCode has been installed"
    }
    else {
        Write-Output "Error locating the VSCode"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error installing VSCode: $ErrorMessage"
}
#endregion

#region paint.net
Write-Output "Installing paint.net"
try {
    start-process -filepath msiexec -ArgumentList "/i ""c:\temp\software\PaintDotNet_x64.msi"" /l*v ""c:\temp\PaintDotNet_x64.msi.log""  /passive TARGETDIR=""$($env:ProgramFiles)\paint.net"" CHECKFORBETAS=0 CHECKFORUPDATES=0 DESKTOPSHORTCUT=0 JPGPNGBMPEDITOR=1" -Wait
    if (Test-Path "C:\Program Files\paint.net") {
        Write-Output "paint.net has been installed"
    }
    else {
        Write-Output "Error locating the paint.net"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error installing paint.net: $ErrorMessage"
}
#endregion

#region Time Zone Redirection
$Name = "fEnableTimeZoneRedirection"
$value = "1"
# Add Registry value
try {
    New-ItemProperty -ErrorAction Stop -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name $name -Value $value -PropertyType DWORD -Force
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services").PSObject.Properties.Name -contains $name) {
        Write-Output "Added time zone redirection registry key"
    }
    else {
        Write-Output "Error locating the Teams registry key"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error adding teams registry KEY: $ErrorMessage"
}
#endregion

#region disable updates 
Write-Output '*** AVD Packer customizer phase *** START OS CONFIG *** Update the recommended OS configuration ***'
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Disable Automatic Updates ***'
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Value '1' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Disable Automatic Updates *** - Exit Code: ' $LASTEXITCODE
#endregion

#region Language pack installation
Write-Output "Entering Language Pack installation $(Get-Date)"

##Disable Language Pack Cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"

#region isomounting helper function
function MountIso ($ISOPath) {
    $global:before = (Get-Volume | Where Driveletter -ne $null ).DriveLetter
    Set-Variable -Name mountVolume -Scope Script -value (Mount-DiskImage -ImagePath $ISOPath -StorageType ISO -PassThru)
    sleep -Seconds 1
    $global:after = (Get-Volume | Where Driveletter -ne $null ).DriveLetter  
    Set-Variable -Name driveLetter -Scope Script -Value (Compare-Object  $global:before $global:after -Passthru)
    return @{
        'driveletter' = $driveLetter
        'mountvolume' = $mountVolume
    }
}
#endregion

#region Add Language Pack + experience pack
$LanguagePack = $tmpDir + '\' + $(Split-Path $LPdownloads['LanguagePack'] -Leaf)
#mount 
Write-Output "Mounting ISO Image: $LanguagePack"
$iso = MountIso $LanguagePack
#provision
Add-AppProvisionedPackage -Online -PackagePath "$($iso['driveletter'])`:\LocalExperiencePack\de-de\LanguageExperiencePack.de-de.Neutral.appx" -LicensePath "$($iso['driveletter'])`:\LocalExperiencePack\de-de\License.xml" -Verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\x64\langpacks\Microsoft-Windows-Client-Language-Pack_x64_de-de.cab" -Verbose
#unmount
Write-Output "Dismounting ISO Image."
dismount-diskimage -InputObject $iso['mountvolume']
#endregion

#region add FOD Pack
$FODPack = $tmpDir + '\' + $(Split-Path $LPdownloads['FODPack'] -Leaf)

Write-Output "Mounting ISO Image: $FODPack"
$iso = MountIso $FODPack
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-LanguageFeatures-Handwriting-de-de-Package~31bf3856ad364e35~amd64~~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-LanguageFeatures-OCR-de-de-Package~31bf3856ad364e35~amd64~~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-LanguageFeatures-Speech-de-de-Package~31bf3856ad364e35~amd64~~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-LanguageFeatures-TextToSpeech-de-de-Package~31bf3856ad364e35~amd64~~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose
Add-WindowsPackage -Online -PackagePath "$($iso['driveletter'])`:\Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab"  -verbose

Write-Output "Dismounting ISO Image."
dismount-diskimage -InputObject $iso['mountvolume']
#endregion

#this part will be 'removed' during sysprep so you need to rerun this 3 lines in a new machine.
$LanguageList = Get-WinUserLanguageList
$LanguageList.Add("de-de")
Set-WinUserLanguageList $LanguageList -force

#region Update Inbox Apps for Multi Language
$InboxApps = $tmpDir + '\' + $(Split-Path $LPdownloads['InboxApps'] -Leaf)
#mount 
Write-Output "Mounting ISO Image: $InboxApps"
$iso = MountIso $InboxApps
[string] $AppsContent = "$($iso['driveletter'])`:\amd64fre\" 
##Update installed Inbox Store Apps##
foreach ($App in (Get-AppxProvisionedPackage -Online)) {
    $AppPath = $AppsContent + $App.DisplayName + '_' + $App.PublisherId
    Write-Host "Handling: $($App.DisplayName) --> $AppPath"
    $licFile = Get-Item $AppPath*.xml
    if ($licFile.Count) {
        $lic = $true
        $licFilePath = $licFile.FullName
    }
    else {
        $lic = $false
    }
    $appxFile = Get-Item $AppPath*.appx*
    if ($appxFile.Count) {
        $appxFilePath = $appxFile.FullName
        if ($lic) {
            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -LicensePath $licFilePath -Verbose
        }
        else {
            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -skiplicense -Verbose
        }
    }
}
Write-Output "Dismounting ISO Image."
dismount-diskimage -InputObject $iso['mountvolume']
#endregion

Write-Output "Finished Language Pack installation $(Get-Date)"
#endregion

#region Office Language Pack installation
#https://www.microsoft.com/en-us/download/details.aspx?id=49117
#downloaded Office Deployment Tool -> created a config file (https://config.office.com/) to add de-de as language -> execute OCT tool to download & install LP
Write-Output "Installing Office Language Pack $(Get-Date)"
try {
    Start-Process -filepath 'c:\temp\software\OCT\setup.exe' -Wait -ErrorAction Stop -ArgumentList '/configure "c:\temp\software\OCT\bftest.xml"'
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error installing Office Language Pack $ErrorMessage"
}
Write-Output "End Office Language Pack $(Get-Date)"
#endregion

#region a lot of stuff
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Specify Start layout for Windows 10 PCs (optional) ***'
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SpecialRoamingOverrideAllowed' -Value '1' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Specify Start layout for Windows 10 PCs (optional) *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Set up time zone redirection ***'
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fEnableTimeZoneRedirection' -Value '1' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Set up time zone redirection *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Disable Storage Sense ***'
# reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 0 /f
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense' -Name 'AllowStorageSenseGlobal' -Value '0' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Disable Storage Sense *** - Exit Code: ' $LASTEXITCODE

# Note: Remove if not required!
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** For feedback hub collection of telemetry data on Windows 10 Enterprise multi-session ***'
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value '3' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** For feedback hub collection of telemetry data on Windows 10 Enterprise multi-session *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Fix Watson crashes ***'
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name "CorporateWerServer*" | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Fix Watson crashes *** - Exit Code: ' $LASTEXITCODE

<# # Note: Remove if not required!
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEYS *** Fix 5k resolution support ***'
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxMonitors' -Value '4' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxXResolution' -Value '5120' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'MaxYResolution' -Value '2880' -PropertyType DWORD -Force | Out-Null
New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs' -Name 'MaxMonitors' -Value '4' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs' -Name 'MaxXResolution' -Value '5120' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs' -Name 'MaxYResolution' -Value '2880' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEYS *** Fix 5k resolution support *** - Exit Code: ' $LASTEXITCODE
 #>

<# Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Temp fix for 20H1 SXS Bug ***'
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs' -Name 'fReverseConnectMode' -Value '1' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET OS REGKEY *** Temp fix for 20H1 SXS Bug *** - Exit Code: ' $LASTEXITCODE
 #>

# Note: Remove if not required!
Write-Output '*** AVD Packer customizer phase *** SET MSIX APPATTACH REGKEYS *** Disable Store auto update ***'
New-Item -Path 'HKLM:\Software\Policies\Microsoft\WindowsStore' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -Value '0' -PropertyType DWORD -Force | Out-Null
Invoke-Expression -Command 'Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable'
Invoke-Expression -Command 'Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable'
Write-Output '*** AVD Packer customizer phase *** SET MSIX APPATTACH REGKEYS *** Disable Store auto update *** - Exit Code: ' $LASTEXITCODE
Write-Output '*** AVD Packer customizer phase *** SET MSIX APPATTACH REGKEYS *** Disable Content Delivery auto download apps that they want to promote to users'
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug' -Name 'ContentDeliveryAllowedOverride' -Value 0x2 -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET MSIX APPATTACH REGKEYS *** Disable Content Delivery auto download apps that they want to promote to users *** - Exit Code: ' $LASTEXITCODE
Write-Output '*** AVD Packer customizer phase *** SET MSIX APPATTACH REGKEYS *** Mount default registry hive ***'
& REG LOAD HKLM\DEFAULT C:\Users\Default\NTUSER.DAT
Start-Sleep -Seconds 5
New-ItemProperty -Path 'HKLM:\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'PreInstalledAppsEnabled' -Value '0' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** SET MSIX APPATTACH REGKEYS *** Mount default registry hive *** - Exit Code: ' $LASTEXITCODE
Write-Output '*** AVD Packer customizer phase *** WE LEAVE DEFAULT USER PROFILE OPEN FOR NEXT SECTION! ***'
# Note: DO NOT PLACE ANYTHING BETWEEN MSIX and OFFICE SECTION As Default User hive is still open!

# OFFICE365 SECTION

# Note: For Settings below it is also recommended to set user settings through GPO's
Write-Output '*** AVD Packer customizer phase *** START OFFICE CONFIG *** Config the recommended Office configuration ***'
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE Regkeys *** Default registry hive is still loaded!***'
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE *** Set InsiderslabBehavior ***'
New-Item -Path 'HKLM:\DEFAULT\SOFTWARE\Policies\Microsoft\office\16.0\common' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\DEFAULT\SOFTWARE\Policies\Microsoft\office\16.0\common' -Name 'InsiderSlabBehavior' -Value '2' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE *** Set InsiderslabBehavior *** - Exit Code: ' $LASTEXITCODE
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE *** Set Outlooks Cached Exchange Mode behavior ***'
New-ItemProperty -Path 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name 'enable' -Value '1' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name 'syncwindowsetting' -Value '1' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name 'CalendarSyncWindowSetting' -Value '1' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name 'CalendarSyncWindowSettingMonths' -Value '1' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE *** Set Outlooks Cached Exchange Mode behavior *** - Exit Code: ' $LASTEXITCODE
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE Regkeys *** Un-mount default registry hive. Still Open from MSIX secioion ***'
[GC]::Collect()
& REG UNLOAD HKLM\DEFAULT
Start-Sleep -Seconds 5
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE Regkeys *** Un-mount default registry hive. Still Open from MSIX secioion *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE Regkeys *** Set Office Update Notifiations behavior ***'
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Name 'hideupdatenotifications' -Value '1' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Name 'hideenabledisableupdates' -Value '1' -PropertyType DWORD -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** CONFIG OFFICE Regkeys *** Set Office Update Notifiations behavior *** - Exit Code: ' $LASTEXITCODE

# Note: When using the Marketplace Image for Windows 10 Enterprise Multu Session with Office Onedrive is already installed correctly (for 20H1). 
# Write-Output '*** AVD Packer customizer phase *** INSTALL ONEDRIVE *** Uninstall Ondrive per-user mode and Install OneDrive in per-machine mode ***'
# Invoke-WebRequest -Uri 'https://aka.ms/OneDriveWVD-Installer' -OutFile 'c:\temp\OneDriveSetup.exe'
# New-Item -Path 'HKLM:\Software\Microsoft\OneDrive' -Force | Out-Null
# Start-Sleep -Seconds 10
# Invoke-Expression -Command 'C:\temp\OneDriveSetup.exe /uninstall'
# New-ItemProperty -Path 'HKLM:\Software\Microsoft\OneDrive' -Name 'AllUsersInstall' -Value '1' -PropertyType DWORD -Force | Out-Null
# Start-Sleep -Seconds 10
# Invoke-Expression -Command 'C:\temp\OneDriveSetup.exe /allusers'
# Start-Sleep -Seconds 10
# Write-Output '*** AVD Packer customizer phase *** CONFIG ONEDRIVE *** Configure OneDrive to start at sign in for all users. ***'
# New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Value 'C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe /background' -Force | Out-Null
# Write-Output '*** AVD Packer customizer phase *** CONFIG ONEDRIVE *** Silently configure user account ***'
# New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive' -Name 'SilentAccountConfig' -Value '1' -PropertyType DWORD -Force | Out-Null
# Write-Output '*** AVD Packer customizer phase *** CONFIG ONEDRIVE *** Redirect and move Windows known folders to OneDrive by running the following command. ***'
# New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive' -Name 'KFMSilentOptIn' -Value $AADTenantID -Force | Out-Null

Write-Output '*** AVD Packer customizer phase *** INSTALL *** Install C++ Redist for RTCSvc (Teams Optimized) ***'
Invoke-WebRequest -Uri 'https://aka.ms/vs/16/release/vc_redist.x64.exe' -OutFile 'c:\temp\vc_redist.x64.exe'
Invoke-Expression -Command 'C:\temp\vc_redist.x64.exe /install /quiet /norestart'
Start-Sleep -Seconds 15
Write-Output '*** AVD Packer customizer phase *** INSTALL *** Install C++ Redist for RTCSvc (Teams Optimized) *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** INSTALL *** Install RTCWebsocket to optimize Teams for WVD ***'
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'IsWVDEnvironment' -Value '1' -PropertyType DWORD -Force | Out-Null
Invoke-WebRequest -Uri 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt' -OutFile 'c:\temp\MMsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi' 
Invoke-Expression -Command 'msiexec /i c:\temp\MMsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi /quiet /l*v C:\temp\MsRdcWebRTCSvc_HostSetup.log ALLUSER=1'
Start-Sleep -Seconds 15
Write-Output '*** AVD Packer customizer phase *** INSTALL *** Install RTCWebsocket to optimize Teams for WVD *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** INSTALL *** Install Teams in Machine mode ***'
Invoke-WebRequest -Uri 'https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true' -OutFile 'c:\temp\Teams.msi'
Invoke-Expression -Command 'msiexec /i C:\temp\Teams.msi /quiet /l*v C:\temp\teamsinstall.log ALLUSER=1 ALLUSERS=1'
Write-Output '*** AVD Packer customizer phase *** INSTALL *** Install Teams in Machine mode *** - Exit Code: ' $LASTEXITCODE
Write-Output '*** AVD Packer customizer phase *** CONFIG TEAMS *** Configure Teams to start at sign in for all users. ***'
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run -Name Teams -PropertyType Binary -Value ([byte[]](0x01, 0x00, 0x00, 0x00, 0x1a, 0x19, 0xc3, 0xb9, 0x62, 0x69, 0xd5, 0x01)) -Force
Start-Sleep -Seconds 45
Write-Output '*** AVD Packer customizer phase *** CONFIG TEAMS *** Configure Teams to start at sign in for all users. *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase *** CONFIG *** Deleting temp folder. ***'
#Get-ChildItem -Path 'C:\temp' -Recurse | Remove-Item -Recurse -Force | Out-Null
#Remove-Item -Path 'C:\temp' -Force | Out-Null
Write-Output '*** AVD Packer customizer phase *** CONFIG *** Deleting temp folder. *** - Exit Code: ' $LASTEXITCODE

Write-Output '*** AVD Packer customizer phase ********************* END *************************'   
#endregion

Stop-Transcript