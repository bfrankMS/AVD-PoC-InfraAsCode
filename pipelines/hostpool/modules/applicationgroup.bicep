param hostPoolName string = ''
param hostPoolRG string = resourceGroup().name
param location string = resourceGroup().location
param tagValues object = {}

var applicationgroupName_var = '${hostPoolName}-DAG'
var hostpoolsID = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${hostPoolRG}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'
var friendlyName = '${hostPoolName} Desktop Application Group'

resource applicationgroupName 'Microsoft.DesktopVirtualization/applicationgroups@2021-02-01-preview' = {
  name: applicationgroupName_var
  location: location
  kind: 'Desktop'
  tags: tagValues
  properties: {
    hostPoolArmPath: hostpoolsID
    description: 'Desktop Application Group created through ARM template'
    friendlyName: friendlyName
    applicationGroupType: 'Desktop'
  }
}
output applicationGroupID string = applicationgroupName.id
output applicationGroupName string = applicationgroupName.name
