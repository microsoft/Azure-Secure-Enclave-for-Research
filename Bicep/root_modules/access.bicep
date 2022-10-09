targetScope = 'subscription'

param location string
param namingStructure string
param deploymentNameStructure string
param vnetAddressPrefixes array
param rdshVmSize string
param rdshPrefix string
param vmCount int
// A custom object with at least id, name, and resourceGroupName properties
param workspaceVNet object

@secure()
param vmAdministratorAccountPassword string

param subwloadname string = ''
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

var avdSubnets = {
  compute: {
    name: 'compute'
    addressPrefix: '172.18.0.0/25'
    privateEndpointNetworkPolicies: 'Disabled'
    serviceEndpoints: []
  }
}
// Create a separate resource group for the VMs
resource avdResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(baseName, '{rtype}', 'rg')
  location: location
  tags: tags
}

// Create the AVD infrastructure resources
module avd '../child_modules/avd.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd')
  scope: avdResourceGroup
  params: {
    namingStructure: namingStructure
    location: location
    tags: tags
  }
}

// Create the AVD VNet
module vnet '../child_modules/network.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd-vnet')
  scope: avdResourceGroup
  params: {
    location: location
    addressPrefixes: vnetAddressPrefixes
    deploymentNameStructure: deploymentNameStructure
    // This replacement ensures that VNet name for the AVD VNet is different than the workspace VNet
    namingStructure: replace(namingStructure, '{rtype}', '{rtype}-avd')
    subnets: avdSubnets
    // Do not specify hubVirtualNetworkId here, because that would only initiate the peering
    // The next module will create a bi-directional peering
  }
}

// Peer the AVD VNet to the workspace VNet, bidirectionally
module vNetPeering '../child_modules/networkPeeringBidirectional.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd-vnet-peer')
  scope: avdResourceGroup
  params: {
    deploymentNameStructure: deploymentNameStructure
    // The AVD VNet is considered the local (because we are peering from here)
    localName: 'access'
    localVNetId: vnet.outputs.vNetId
    localVNetName: vnet.outputs.vNetName
    remoteName: 'workspace'
    remoteVNetId: workspaceVNet.id
    remoteVNetName: workspaceVNet.name
    remoteVNetResourceGroupName: workspaceVNet.resourceGroupName
    allowLocalVirtualNetworkAccess: true
    allowRemoteVirtualNetworkAccess: false
  }
}

// Create the AVD session hosts
module avdCompute '../child_modules/avdCompute.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avdvm-vms')
  scope: avdResourceGroup
  params: {
    location: location
    hostPoolRegistrationToken: avd.outputs.hostpoolRegistrationToken
    deploymentNameStructure: deploymentNameStructure
    vmCount: vmCount
    rdshVmSize: rdshVmSize
    rdshPrefix: rdshPrefix
    hostPoolName: avd.outputs.hostpoolName
    avdSubnetId: vnet.outputs.subnetIds[0]
    tags: tags
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
  }
}
