#this will be our temp folder - need it for download / logging
$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force }

#write a log file with the same name of the script
Start-Transcript "$tmpDir\$($SCRIPT:MyInvocation.MyCommand).log"

#To install AD we need PS support for AD first
$features = @("RSAT-AD-Tools", "RSAT-AD-AdminCenter", "RSAT-ADDS-Tools", "RSAT-AD-PowerShell", "RSAT-ADDS", "RSAT-ADLDS", "RSAT-AD-Tools", "RSAT-DNS-Server", "GPMC" )
Install-WindowsFeature -Name $features -Verbose 

#Download some tools. e.g. for benchmarking storage IO
$Downloads = @( 
    "https://github.com/microsoft/ntttcp/releases/download/v5.35/NTttcp.exe", 
    "https://github.com/microsoft/diskspd/releases/download/v2.0.21a/DiskSpd.zip",
    "https://github.com/microsoft/latte/releases/download/v0/latte.exe"
)

foreach ($download in $Downloads) {
    $downloadPath = $tmpDir + "\$(Split-Path $download -Leaf)"
    if (!(Test-Path $downloadPath )) {
        #download if not there
        $client = new-object System.Net.WebClient
        $client.DownloadFile($download,$downloadPath)
        $client.Dispose()
    }
}

#disable IE Enhanced Security Configuration
$ieESCAdminPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$ieESCUserPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
$ieESCAdminEnabled = (Get-ItemProperty -Path $ieESCAdminPath).IsInstalled
$ieESCAdminEnabled = 0
Set-ItemProperty -Path $ieESCAdminPath -Name IsInstalled -Value $ieESCAdminEnabled
Set-ItemProperty -Path $ieESCUserPath -Name IsInstalled -Value $ieESCAdminEnabled

stop-transcript
