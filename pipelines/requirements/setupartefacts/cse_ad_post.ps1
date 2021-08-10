﻿param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $OUName,

    [Parameter(Mandatory=$True,Position=2)]
    [string] $AVDUsersPassword
)

#this will be our temp folder - need it for download / logging
$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force}

#write a log file with the same name of the script
Start-Transcript "$tmpDir\$($SCRIPT:MyInvocation.MyCommand).log"

Import-Module ActiveDirectory
$DomainPath = $((Get-ADDomain).DistinguishedName) # e.g."DC=contoso,DC=azure"

#region add OU for 'AVDUsers'
    "Creating OU:{0} in Domain:{1} on Server:{2}" -f $OUName,$DomainPath,$hostname
    New-ADOrganizationalUnit -Name:$OUName -Path:$DomainPath -ProtectedFromAccidentalDeletion:$true 
    Set-ADObject -Identity:"OU=$OUName,$DomainPath" -ProtectedFromAccidentalDeletion:$true 
    
    for ($i = 1; $i -le 10; $i++)
    { 
        New-ADOrganizationalUnit -Name:"HostPool$i" -Path:"OU=$OUName,$DomainPath" -ProtectedFromAccidentalDeletion:$true 
    }
#endregion 

#region add Sec Group "AVD Users"
    New-ADGroup -GroupCategory:"Security" -GroupScope:"Global" -Name:"AVD Users" -Path:"OU=$OUName,$DomainPath" -SamAccountName:"AVD Users" 
#endregion

#disable IE Enhanced Security Configuration
$ieESCAdminPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$ieESCUserPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
$ieESCAdminEnabled = (Get-ItemProperty -Path $ieESCAdminPath).IsInstalled
$ieESCAdminEnabled = 0
Set-ItemProperty -Path $ieESCAdminPath -Name IsInstalled -Value $ieESCAdminEnabled
Set-ItemProperty -Path $ieESCUserPath -Name IsInstalled -Value $ieESCAdminEnabled

#region create some AVD test users
    $ADPath = "OU=$OUName,$DomainPath"

    for ($i = 1; $i -le 15; $i++)
    { 
        $userName = "AVDUser$i"
        $Identity = "CN=$userName" +"," +$ADPath
        if ((Get-ADUser -Identity $Identity) -ne $null)  {Write-Output "$Identity already exists"; continue}
        $user = New-ADUser -Path:$ADPath `
        -Name $userName `
        -DisplayName $userName `
        -Enabled $false `
        -PassThru -UserPrincipalName $("$userName@"+$((Get-ADDomain).Forest))
        
        #Add-ADPrincipalGroupMembership -Identity:$user.DistinguishedName -MemberOf:"CN=Remote Desktop Users,CN=Builtin,DC=$($DomainName.Split('.')[0]),DC=$($DomainName.Split('.')[1])"
        Set-ADGroup -Add:@{'Member'="CN=$userName,$ADPath"} -Identity:"CN=AVD Users,$ADPath" 

        #Convert to secure string
        $Password = ConvertTo-SecureString "$AVDUsersPassword" -AsPlainText -Force 

        Set-ADAccountPassword -Identity:$user.DistinguishedName -NewPassword:$Password -Reset:$true 
        Set-ADObject -Identity:$user.DistinguishedName -Replace:@{"userAccountControl"="512"}   #enable account
        Set-ADUser -ChangePasswordAtLogon:$false -Identity:$user.DistinguishedName -PasswordNeverExpires:$true 
    }
#endregion

stop-transcript
