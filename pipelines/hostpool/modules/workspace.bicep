param workspaceName string = ''
param tagValues object
param workspaceFriendlyName string = 'Cloud Workspace'

@description('description')
param applicationGroups array = [
 ] 
// e.g. '/subscriptions/f55edc34-b2f6-42f6-b100-9f68e5110bb7/resourceGroups/rg-MS-avd-hostpools/providers/Microsoft.DesktopVirtualization/applicationgroups/HP11-DAG'

@description('name of your avd workspace')
param location string = resourceGroup().location

resource workspacesName_resource 'Microsoft.DesktopVirtualization/workspaces@2021-02-01-preview' = {
  name: workspaceName
  location: location
  tags: tagValues
  properties: {
    friendlyName: workspaceFriendlyName
    applicationGroupReferences: applicationGroups
  }
}
