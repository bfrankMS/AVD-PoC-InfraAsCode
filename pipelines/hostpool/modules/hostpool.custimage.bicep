@description('(Required when vmImageType = Gallery) Gallery image Offer.')
param vmGalleryImageOffer string = 'office-365'

@description('(Required when vmImageType = Gallery) Gallery image Publisher.')
param vmGalleryImagePublisher string = 'MicrosoftWindowsDesktop'

@description('(Required when vmImageType = Gallery) Gallery image SKU.')
param vmGalleryImageSKU string = '20h2-evd-o365pp'

@description('The name of the hostpool')
param hostpoolName string

@description('This prefix will be used in combination with the VM number to create the VM name. This value includes the dash, so if using \'rdsh\' as the prefix, VMs would be named “rdsh-0”, “rdsh-1”, etc. You should use a unique prefix to reduce name collisions in Active Directory.')
param vmPrefix string = take(toLower('${hostpoolName}-vm'),10)

@description('This is the suffix to the vm names. VM will be named \'[vmPrefix]-[vmInstanceSuffixes]\'')
param vmInstanceSuffixes array = [
  '0'
  '1'
]

@allowed([
  'Premium_LRS'
  'StandardSSD_LRS'
  'Standard_LRS'
  'UltraSSD_LRS'
])
@description('The VM disk type for the VM: HDD or SSD.')
param vmDiskType string = 'Standard_LRS'

@description('The size of the session host VMs.')
param vmSize string = 'Standard_DS2_v2' // 'Standard_A2'

/*
Standard_B2ms   
Standard_B2s    
Standard_DS2_v2 
Standard_F2s    
Standard_D2s_v3 
Standard_D2s_v4 
Standard_F2s_v2 
Standard_D2as_v4
*/
@description('Enables Accelerated Networking feature, notice that VM size must support it, this is supported in most of general purpose and compute-optimized instances with 2 or more vCPUs, on instances that supports hyperthreading it is required minimum of 4 vCPUs.')
param enableAcceleratedNetworking bool = false

@description('The username for the admin.')
param administratorAccountUsername string

@description('The password that corresponds to the existing domain username.')
@secure()
param administratorAccountPassword string

@description('The name of the virtual network the VMs will be connected to.')
param existingVnetName string

@description('The subnet the VMs will be placed in.')
param existingSubnetName string

@description('The resource group containing the existing virtual network.')
param virtualNetworkResourceGroupName string

@description('Location for all resources to be created in.')
param location string = resourceGroup().location

@description('The rules to be given to the new network security group')
param networkSecurityGroupRules array = []

@description('The tags to be assigned to the resources')
param tagValues object = {
  creator: 'bfrank'
  env: 'avdPoc'
}

@description('The reference to your image')
param imageref_id string = ''

@description('OUPath for the domain join')
param ouPath string = 'OU=HostPool1,OU=AVD,DC=contoso,DC=local'

@description('Domain to join')
param domain string = ''
param tokenExpirationTime string = dateTimeAdd(utcNow('yyyy-MM-dd T00:00:00'), 'P1D', 'o')

var WvdAgentArtifactsLocation = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1-25-2021.zip'
var artifactsLocationSASToken = ''
var existingDomainUsername = first(split(administratorAccountUsername, '@'))
var domain_var = ((domain == '') ? last(split(administratorAccountUsername, '@')) : domain)
var storageAccountType = vmDiskType
var newNsgName_var = '${vmPrefix}-nsg'
var subnet_id = resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', existingVnetName, existingSubnetName)

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2021-02-01-preview' = {
  name: hostpoolName
  location: location
  tags: tagValues
  properties:{
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: 5
    description: 'first avd host pool'
    friendlyName: 'friendly name'
    preferredAppGroupType: 'Desktop'
    registrationInfo: {
        expirationTime: tokenExpirationTime
        registrationTokenOperation: 'Update'
    }
  }
}

resource newNsgName 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: newNsgName_var
  location: location
  tags: tagValues
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource vmPrefix_vmInstanceSuffixes_nic 'Microsoft.Network/networkInterfaces@2018-11-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}-${item}-nic'
  location: location
  tags: tagValues
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_id
          }
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
    networkSecurityGroup: json('{"id": "${newNsgName.id}"}')
  }
  dependsOn: [
    newNsgName
  ]
}]

resource vmPrefix_vmInstanceSuffixes 'Microsoft.Compute/virtualMachines@2018-10-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}-${item}'
  location: location
  tags: tagValues
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: concat(vmPrefix,'-', item)
      adminUsername: existingDomainUsername
      adminPassword: administratorAccountPassword
    }
    storageProfile: {
      imageReference: {
        id: imageref_id
            }
      osDisk: {
        createOption: 'FromImage'
        name: '${vmPrefix}-${item}-osdisk'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${vmPrefix}-${item}-nic')
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Client'
  }
  dependsOn: [
    vmPrefix_vmInstanceSuffixes_nic
  ]
}]

resource vmPrefix_vmInstanceSuffixes_joindomain 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}-${item}/joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domain_var
      ouPath: ouPath
      user: '${administratorAccountUsername}@${domain_var}'
      restart: 'true'
      options: '3'
    }
    protectedSettings: {
      password: administratorAccountPassword
    }
  }
  dependsOn: [
    vmPrefix_vmInstanceSuffixes
  ]
}]

resource vmPrefix_vmInstanceSuffixes_dscextension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}-${item}/dscextension'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: concat(WvdAgentArtifactsLocation, artifactsLocationSASToken)
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostpoolName
        registrationInfoToken: hostPool.properties.registrationInfo.token
      }
    }
    protectedSettings: {}
  }
  dependsOn: [
    vmPrefix_vmInstanceSuffixes_joindomain
  ]
}]
