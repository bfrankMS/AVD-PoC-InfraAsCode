<# 
    This script will create a service principal in your azure subscription 
    that can be used in the AVD PoC devops pipelines 
    requires: PowerShell AZ modules installed (install-module AZ)
    execution location: run this locally (cloudshell may not work)
    dependency: Execute this before you start any azure devops pipeline -> add your Service Principal in devops -> Project settings -> service connections -> resource manager (manual) -> type in the values you get as output here.
#>

#you need to login again although you already have the portal access (e.g. when using cloud shell)
az login


#adjust the vars to your needs!
$SPName = 'yourazuredevopsserviceconnection'         #your value here!
$location = 'northeurope'     #your value here!  -> should be the target region you are planing to use for this PoC
$keyvaultnamePrefix = 'kv-avdPoc'   #leave this as is - (otherwhise you would need to change this in the pipeline variable file consistently)
$rgForSharedResources = 'rg-avdPoC-shared'  #leave this as is - (otherwhise you would need to change this in the pipeline variable file consistently)


# create Service Principal (it needs to be owner to set permissions on azure artefacts - especially the application group users)
$sp = az ad sp create-for-rbac -n "$SPName" --role 'owner'

# this role is needed for the service principal to upload files to an azure storage account using azure devops.
az role assignment create --assignee "$($($sp | ConvertFrom-Json).appId)" --role 'Storage Blob Data Contributor'

# the SP needs to query the AAD for the object ID of user groups to set Azure RBAC roles on the FSLogix FShare
az ad app permission add --id "$(($sp | ConvertFrom-Json).appId)" --api 00000002-0000-0000-c000-000000000000 --api-permissions 5778995a-e1bf-45b8-affa-663a9f3f4d04=Role
az ad app permission grant --id "$(($sp | ConvertFrom-Json).appId)" --api 00000002-0000-0000-c000-000000000000

# Graph API permissions Directory.Read.All for Service principal (WVDAdmin)
az ad app permission add --id "$(($sp | ConvertFrom-Json).appId)" --api 00000003-0000-0000-c000-000000000000 --api-permissions 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
az ad app permission grant --id "$(($sp | ConvertFrom-Json).appId)" --api 00000003-0000-0000-c000-000000000000

az ad app permission admin-consent --id "$($($sp | ConvertFrom-Json).appId.trim())" --verbose



# creating a RG if it does not exist.
az group create --location $location --resource-group $rgForSharedResources

# createing an unique keyvault name.
$keyvaultname = $keyvaultnamePrefix + $(get-random -Minimum 1000 -Maximum 9999)
Write-Host "!Remember! the name of your keyvault: $keyvaultname" -ForegroundColor DarkYellow 

# the credential details are stored in a key vault - so that a later pipeline can access it and perform tasks like logon to azure within an devops job.
$keyvaultid = az keyvault create --name "$keyvaultname" --resource-group "$rgForSharedResources" --location "$location" --enable-rbac-authorization --query id -o tsv
#make sp "Key Vault Secrets Officer" on keyvault scope
az role assignment create --assignee $($sp | ConvertFrom-Json).appId --role "Key Vault Secrets Officer" --scope "$keyvaultid"

# save keyvault from accidental deletion using a lock
az lock create --name "preventAccidentialDeletion" --resource-group "$rgForSharedResources" --lock-type CanNotDelete --resource-type Microsoft.KeyVault/vaults --resource "$keyvaultname"

#get the current user and allow it to the key vault.
$context = az account show | convertfrom-json
az role assignment create --assignee "$($context.user.name)" --role "Key Vault Secrets Officer" --scope "$keyvaultid"

#the above assignment takes some time therefore we wait
Start-Sleep -Seconds 30
#! wait a little longer if you get: "Caller is not authorized to perform action on resource. If role assignments, deny assignments or role definitions were changed recently, please observe propagation time...."

$subscriptionID = az account show --query id --output tsv
$subscriptionName = az account show --query name --output tsv

#this stores the secrets
az keyvault secret set --vault-name "$keyvaultname" --name "spappid" --value "$(($sp | ConvertFrom-Json).appId)"
az keyvault secret set --vault-name "$keyvaultname" --name "sppassword" --value "$(($sp | ConvertFrom-Json).password)"
az keyvault secret set --vault-name "$keyvaultname" --name "subscriptionid" --value "$subscriptionID"
az keyvault secret set --vault-name "$keyvaultname" --name "tenantid" --value "$(($sp | ConvertFrom-Json).tenant)"

#need to do this again to grant the consent - maybe a timing issue.
az ad app permission admin-consent --id "$($($sp | ConvertFrom-Json).appId.trim())"

$output = @"
=====please note down your:=====

Subscription ID: $subscriptionID
Subscription Name: $subscriptionName

Keyvault name: $keyvaultname

Service principals details:$($sp | convertfrom-json | Out-String)
"@

Write-Host $output -ForegroundColor Magenta