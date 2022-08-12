param adfName string
param privateStorageAccountId string
param privateStorageAccountName string

param managedVNetName string = 'default'

resource privateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: '${adfName}/${managedVNetName}/pe-${privateStorageAccountName}-dfs'
  properties: {
    privateLinkResourceId: privateStorageAccountId
    groupId: 'dfs'
  }
}

output privateEndpointId string = privateEndpoint.properties.privateLinkResourceId
