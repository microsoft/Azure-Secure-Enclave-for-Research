param location string
param namingStructure string
param subwloadname string = ''
param addressPrefixes array
param dnsServers array = []
param subnets object
param nsgSecurityRules array = []
param defaultRouteNextHop string = ''
param hubVirtualNetworkId string = ''
param tags object = {}

var customDNS = !empty(dnsServers)
var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

// create vnet
resource virtual_network 'Microsoft.Network/virtualNetworks@2021-05-01' = {
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
        privateEndpointNetworkPolicies: !empty(s.value.privateEndpointNetworkPolicies) ? 'Disabled' : s.value.privateEndpointNetworkPolicies
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

// create nsgs
resource networkSecurityGroups 'Microsoft.Network/networkSecurityGroups@2021-05-01' = [for s in items(subnets): {
  name: 'nsg-${s.value.name}'
  location: location
  properties: {
    securityRules: !empty(nsgSecurityRules) ? nsgSecurityRules : json('null')
  }
  tags: tags
}]

// create route tables
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

resource peerToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = if (!empty(hubVirtualNetworkId)) {
  name: '${virtual_network.name}-to-${last(split(hubVirtualNetworkId, '/'))}'
  parent: virtual_network
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: hubVirtualNetworkId
    }
    useRemoteGateways: false
  }
}

resource pepSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${virtual_network.name}/${subnets['privateEndpoints'].name}'
}

resource workloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${virtual_network.name}/${subnets['workload'].name}'
}

output vnetId string = virtual_network.id
output pepSubnetId string = pepSubnet.id
output workloadSubnetId string = workloadSubnet.id
