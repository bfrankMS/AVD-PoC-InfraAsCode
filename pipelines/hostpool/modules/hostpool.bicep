@description('The name of the hostpool')
param hostpoolName string

@description('Location for all resources to be created in.')
param location string = resourceGroup().location

@description('The tags to be assigned to the resources')
param tagValues object = {
  creator: 'bfrank'
  env: 'avdPoc'
}

param tokenExpirationTime string = dateTimeAdd(utcNow('yyyy-MM-dd T00:00:00'),'P1D','o')

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

output registrationInfoToken string = reference(hostPool.id).registrationInfo.token


