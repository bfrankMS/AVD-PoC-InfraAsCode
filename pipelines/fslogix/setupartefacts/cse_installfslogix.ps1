<#
    purpose: This will configure FSLogix to use Azure Files.
    run this on: a session host (aka desktop)
    by bfrank
    reference: https://docs.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-active-directory-enable
#>

#this will be our temp folder - need it for download / logging
$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force }

#write a log file with the same name of the script
Start-Transcript "$tmpDir\$($SCRIPT:MyInvocation.MyCommand).log" -Force -Append

#downloading FSLogix.
Write-Output "downloading fslogix"

$tempPath = "$tmpDir\FSLogix"
$destinationPath = "$tmpDir\FSLogix.zip"

if (!(Test-Path $destinationPath)) {
    "downloading fslogix"
    #Invoke-WebRequest -Uri "https://aka.ms/fslogix_download" -OutFile $destinationPath -verbose
    #Start-BitsTransfer "https://aka.ms/fslogix_download" $destinationPath -Priority High -RetryInterval 60 -Verbose -TransferType Download
    $client = new-object System.Net.WebClient
    $client.DownloadFile("https://aka.ms/fslogix_download",$destinationPath)
    $client.Dispose()
    Expand-Archive $destinationPath -DestinationPath $tempPath -Force -verbose
}


#installing FSLogix
Write-Output "installing fslogix"
Start-Process -FilePath "$tempPath\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet" -Wait

#add administrator / domain admins to fslogix exclude local group
$FSLogixLocalGroups = Get-LocalGroup | Where-Object name -like "fslogix *exclude*"
foreach ($FSLogixLocalGroup in $FSLogixLocalGroups) {
    $FSLogixLocalGroup
    $fqdn = (Get-WmiObject Win32_ComputerSystem).Domain
    Add-LocalGroupMember -Group $FSLogixLocalGroup -Member "$fqdn\Domain Admins", "Administrators" -Verbose -ErrorAction SilentlyContinue
}

#configuring FSLogix
Write-Output "writing fslogix keys"

Stop-Transcript