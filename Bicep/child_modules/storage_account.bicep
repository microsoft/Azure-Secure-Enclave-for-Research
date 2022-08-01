param location string
param namingStructure string
param subwloadname string
param containerNames array
param skuName string = 'Standard_LRS'
param privatize bool = false
param vnetId string = ''
param subnetId string = ''
param principalIds array = []
param tags object = {}

var assignRole = !empty(principalIds)
var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')
var stgNameClean = take(replace(guid(subscription().id, resourceGroup().id, baseName), '-', ''), 22)
var endpoint = 'privatelink.blob.${environment().suffixes.storage}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: 'st${stgNameClean}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    isHnsEnabled: true
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privatize ? 'Deny' : 'Allow' // force deny inbound traffic
    }
    publicNetworkAccess: privatize ? 'Disabled' : 'Enabled'
  }
  tags: tags
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = [for c in containerNames: {
  parent: blobServices
  name: c
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = if (privatize) {
  name: replace(baseName, '{rtype}', 'pep')
  location: location
  tags: {}
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: replace(baseName, '{rtype}', 'pep')
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privatelink_blob_core_windows_net 'Microsoft.Network/privateDnsZones@2018-09-01' = if (privatize) {
  name: endpoint
  location: 'global'
  properties: {}
  tags: tags
}

resource privateEndpointDNSGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-03-01' = if (privatize) {
  name: '${privateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob-core-windows-net'
        properties: {
          privateDnsZoneId: privatelink_blob_core_windows_net.id
        }
      }
    ]
  }
}

resource privatelink_blob_core_windows_net_virtualNetworkId 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = if (privatize) {
  name: '${endpoint}/${uniqueString(vnetId)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
  dependsOn: [
    privatelink_blob_core_windows_net
  ]
}

// Assign Storage Blob data contrib to principalId if sent to this module
resource rbacAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for i in principalIds: if (assignRole) {
  name: guid('rbac-${storageAccount.name}-${i}')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: i
    principalType: 'ServicePrincipal'
  }
}]

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
