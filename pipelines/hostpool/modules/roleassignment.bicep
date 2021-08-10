param principalID string
param appGroupName string
param wvdusersrole string = newGuid()

var roledefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')

resource targetscope 'Microsoft.DesktopVirtualization/applicationGroups@2021-03-09-preview' existing = {
  name: appGroupName
}

resource role 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: wvdusersrole
  scope: targetscope
  properties: {
    roleDefinitionId: roledefinitionId
    principalId: principalID
  }
}
