param localVNetName string
param remoteVNetId string

param localName string
param remoteName string

param allowVirtualNetworkAccess bool = false

resource localVNetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-05-01' = {
  name: '${localVNetName}/peer-${localName}-to-${remoteName}'
  properties: {
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVNetId
    }
  }
}
