param deploymentNameStructure string

param localVNetName string
param remoteVNetName string
param localVNetId string
param remoteVNetId string

param remoteVNetResourceGroupName string

param localName string
param remoteName string

param allowLocalVirtualNetworkAccess bool = false
param allowRemoteVirtualNetworkAccess bool = false

resource remoteVNetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: remoteVNetResourceGroupName
  scope: subscription()
}

module localToRemotePeering 'networkPeering.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd-vnet-peer-local')
  params: {
    localName: localName
    localVNetName: localVNetName
    remoteName: remoteName
    remoteVNetId: remoteVNetId
    allowVirtualNetworkAccess: allowLocalVirtualNetworkAccess
  }
}

module remoteToLocalPeering 'networkPeering.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd-vnet-peer-remote')
  scope: remoteVNetResourceGroup
  // Two peering operations cannot run in parallel
  dependsOn: [
    localToRemotePeering
  ]
  params: {
    localName: remoteName
    localVNetName: remoteVNetName
    remoteName: localName
    remoteVNetId: localVNetId
    allowVirtualNetworkAccess: allowRemoteVirtualNetworkAccess
  }
}
