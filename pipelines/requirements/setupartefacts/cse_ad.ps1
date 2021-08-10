﻿param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $DomainName,

    [Parameter(Mandatory=$True,Position=2)]
    [string] $Password
)

#this will be our temp folder - need it for download / logging

$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force}

#write a log file with the same name of the script
Start-Transcript "$tmpDir\$($SCRIPT:MyInvocation.MyCommand).log"


#To install AD we need PS support for AD first
Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
Import-Module ActiveDirectory


#Do we find Data disks (raw by default) in this VM? 
$RawDisks = Get-Disk | where PartitionStyle -eq "RAW"

$driveLetters = ("f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")

$i = 0
foreach ($RawDisk in $RawDisks)
{
    $currentDriveLetter = $driveLetters[$i]

    New-Volume -DiskNumber $RawDisk.Number -FriendlyName "Data$i" -FileSystem NTFS -DriveLetter $currentDriveLetter
    $i++
}

#Do Domain install
#on prem you could install AD database to OS disk - AD in Azure VM this is not recommended!
#https://docs.microsoft.com/en-us/previous-versions/orphan-topics/azure.100/jj156090(v=azure.100)
#To Do: for Active Directory database storage You need to change default storage location from C:\ 
#Store the database, logs, and SYSVOL on the either same data disk or separate data disks e.g.
#-DatabasePath "e:\NTDS" -SysvolPath "e:\SYSVOL" -LogPath "e:\Logs"
#Set the Host Cache Preference setting on the Azure data disk for NONE. This prevents issues with write caching for AD DS operations.

$SecurePassword = ConvertTo-SecureString "$Password" -AsPlainText -Force

#Do we have Data Disk? 
$DataDisk0 = Get-Volume -FileSystemLabel "Data0" -ErrorAction SilentlyContinue

switch ($DataDisk0 -ne $null)
{
    'True'      #Active Directory database storage on first Data Disk 
    {
        $drive = "$($DataDisk0.DriveLetter):"
        Install-ADDSForest -DomainName "$DomainName" -DatabasePath "$drive\NTDS" -SysvolPath "$drive\SYSVOL" -LogPath "$drive\Logs" -ForestMode Default -DomainMode Default -InstallDns:$true -SafeModeAdministratorPassword $SecurePassword -CreateDnsDelegation:$false -NoRebootOnCompletion:$true -Force:$true
    }
    
    #nope - not recommended 
    Default 
    {
        Install-ADDSForest -DomainName "$DomainName" -ForestMode Default -DomainMode Default -InstallDns:$true -SafeModeAdministratorPassword $SecurePassword -CreateDnsDelegation:$false -NoRebootOnCompletion:$true -Force:$true
    }
}

#add some DNS forwarders to our DNS server to enable external name resolution
Add-DnsServerForwarder -IPAddress 168.63.129.16  #add azure intrinsic Name server - this works when VM is in Azure / when onprem you need DNS proxy in azure

#download the AD connect tool to synch with AAD
$Downloads = @( `
    "https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi")

    foreach ($download in $Downloads)
    {
        $downloadPath = $tmpDir + "\$(Split-Path $download -Leaf)"
        if (!(Test-Path $downloadPath ))    #download if not there
        {
            #start-bitstransfer "$download" "$downloadPath" -Priority High -RetryInterval 60 -Verbose -TransferType Download #wait until downloaded.
            $client = new-object System.Net.WebClient
            $client.DownloadFile($download,$downloadPath)
            $client.Dispose()
            #Get-BitsTransfer -Verbose -AllUsers
        }
    }

# enabling TLS 1.2 requirement for ADConnect
# https://docs.microsoft.com/en-us/azure/active-directory/hybrid/reference-connect-tls-enforcement
New-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
Write-Host 'TLS 1.2 has been enabled.'

stop-transcript
