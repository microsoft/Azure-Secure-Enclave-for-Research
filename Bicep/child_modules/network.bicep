param location string
param namingStructure string
param addressPrefixes array
param subnets object
param deploymentNameStructure string

param subwloadname string = ''
param dnsServers array = []
param nsgSecurityRules array = []
param defaultRouteNextHop string = ''
param hubVirtualNetworkId string = ''
param tags object = {}

var customDNS = !empty(dnsServers)
var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

// Create a Virtual Network
resource vNet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: replace(baseName, '{rtype}', 'vnet')
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    dhcpOptions: customDNS ? {
      dnsServers: dnsServers
    } : json('null')
    subnets: [for (s, index) in items(subnets): {
      name: s.value.name
      properties: {
        addressPrefix: s.value.addressPrefix
        // If no private endpoint policy setting is specified, assume Disabled
        privateEndpointNetworkPolicies: empty(s.value.privateEndpointNetworkPolicies) ? 'Disabled' : s.value.privateEndpointNetworkPolicies
        networkSecurityGroup: {
          id: networkSecurityGroups[index].id
        }
        routeTable: {
          id: routeTables[index].id
        }
      }
    }]
  }
  tags: tags
}

// Create a network security group for each subnet
resource networkSecurityGroups 'Microsoft.Network/networkSecurityGroups@2021-05-01' = [for (s, i) in items(subnets): {
  name: 'nsg-${s.value.name}'
  location: location
  properties: {
    securityRules: (!empty(nsgSecurityRules) && length(nsgSecurityRules) >= (i + 1)) ? (!empty(nsgSecurityRules[i]) ? nsgSecurityRules[i] : json('null')) : json('null')
  }
  tags: tags
}]

// Create a route table for each subnet
resource routeTables 'Microsoft.Network/routeTables@2021-05-01' = [for s in items(subnets): {
  name: 'rt-${s.value.name}'
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: !empty(defaultRouteNextHop) ? [
      {
        name: 'default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: defaultRouteNextHop
          nextHopType: 'VirtualAppliance'
        }
      }
    ] : json('null')
  }
  tags: tags
}]

// Peer the new workspace VNet to a hub VNet, if specified
// TODO: Create other side of the peering
module peerToHubModule 'networkPeering.bicep' = if (!empty(hubVirtualNetworkId)) {
  name: replace(deploymentNameStructure, '{rtype}', 'net-peer')
  params: {
    localName: 'workspace'
    localVNetName: vNet.name
    remoteName: 'hub'
    remoteVNetId: hubVirtualNetworkId
    allowVirtualNetworkAccess: false
  }
}

// Get the subnets' IDs in the same order as in the parameter array
// The value of vnet.subnets might be out of order
resource subnetRes 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = [for subnet in items(subnets): {
  name: subnet.value.name
  parent: vNet
}]

output vNetId string = vNet.id
// Ensure the subnet IDs are output in the same order as they were provided
// See https://github.com/Azure/bicep/discussions/4953 for background on this technique
output subnetIds array = [for (subnet, i) in items(subnets): subnetRes[i].id]
output vNetName string = vNet.name
output vNet object = {
  id: vNet.id
  name: vNet.name
  resourceGroupName: resourceGroup().name
}
