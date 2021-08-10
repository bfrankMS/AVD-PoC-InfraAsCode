param currentDate string = utcNow('dd-MM-yyyy_HH_mm')
param location string = resourceGroup().location

@secure()
param administratorAccountPassword string
param administratorAccountUsername string
param domain string
param ouPath string
param subnet string
param vnet string
param vnetrg string
param vmPrefix string = '${hostpoolName}-vm'

param hostpoolName string = 'HP1'
param vmNameSuffixes array = [
  0
  1
]

param tagValues object = {
  CreatedBy: 'BICEPDeployment'
  deploymentDate: currentDate
  Environment: 'PoC'
  Service: 'AVD'
}

param enableAcceleratedNetworking bool= false
param vmDiskType string = 'StandardSSD_LRS'
param vmSize string = 'Standard_DS2_v2'
param custimage bool = false
param imageref string = ''  // if custimage=true you have to specify a resource ID to an existing azure vm image here
param vmGalleryImageOffer string =  'office-365'
param vmGalleryImagePublisher string =  'MicrosoftWindowsDesktop'
param vmGalleryImageSKU string =  '20h2-evd-o365pp'



//this module will deploy a hostpool based on a custom VM image (existing)
module hostpoolcust 'modules/hostpool.custimage.bicep' = if(custimage == true) {
  name: 'hostpool_img_${currentDate}'
  params: {
    tagValues: tagValues
    location: location
    administratorAccountPassword: administratorAccountPassword
    administratorAccountUsername: administratorAccountUsername
    domain: domain
    hostpoolName: hostpoolName
    ouPath: ouPath
    existingSubnetName: subnet
    existingVnetName: vnet
    virtualNetworkResourceGroupName: vnetrg
    vmPrefix: vmPrefix
    vmInstanceSuffixes: vmNameSuffixes
    enableAcceleratedNetworking: enableAcceleratedNetworking
    vmDiskType: vmDiskType
    vmSize: vmSize
    imageref_id: imageref
  }
}

//will create a hostpool with vms that are based on a gallery item.
module hostpoolgallery 'modules/hostpool.gallery.bicep' = if(custimage == false) {
  name: 'hostpool_gall_${currentDate}'
  params: {
    tagValues: tagValues
    location: location
    administratorAccountPassword: administratorAccountPassword
    administratorAccountUsername: administratorAccountUsername
    domain: domain
    hostpoolName: hostpoolName
    ouPath: ouPath
    existingSubnetName: subnet
    existingVnetName: vnet
    virtualNetworkResourceGroupName: vnetrg
    vmPrefix: vmPrefix
    vmInstanceSuffixes: vmNameSuffixes
    enableAcceleratedNetworking: enableAcceleratedNetworking
    vmDiskType: vmDiskType
    vmSize: vmSize
    vmGalleryImageOffer: vmGalleryImageOffer
    vmGalleryImagePublisher: vmGalleryImagePublisher
    vmGalleryImageSKU: vmGalleryImageSKU
    }
}
