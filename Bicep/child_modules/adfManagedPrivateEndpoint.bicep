param adfName string
param privateStorageAccountId string
param privateStorageAccountName string

// TODO: Hardcoded managed VNet name ('default')
resource privateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: '${adfName}/default/pe-${privateStorageAccountName}-dfs'
  properties: {
    privateLinkResourceId: privateStorageAccountId
    groupId: 'dfs'
  }
}

output privateEndpointId string = privateEndpoint.properties.privateLinkResourceId
