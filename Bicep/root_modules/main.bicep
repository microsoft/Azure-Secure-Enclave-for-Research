targetScope = 'subscription'

param deploymentTime string = utcNow()
param location string = deployment().location
@allowed([
  'dev'
  'tst'
  'prd'
  'box'
])
param environment string
param workspaceName string
param approverEmail string
param sequence int = 1
param tags object = {}

@secure()
param vmAdministratorAccountPassword string

// Optional parameters
param avdAccess bool = true
param rdshVmSize string = 'Standard_D2s_v3'
param vmCount int = 1
param virtualNetwork object = {}
param hubVirtualNetworkId string = ''
param defaultRouteNextHop string = ''
param existingPrivateEndpointSubnetId string = ''
param privateStorage object = {}
param logAnalytics object = {}
param userAssignedManagedIdentity object = {}
param pipelineName string = 'pipe-data_move'

param workspaceVNetAddressPrefixes array = [
  '172.17.0.0/24'
]

param accessVNetAddressPrefixes array = [
  '172.18.0.0/24'
]

//########################################################################//
//                                                                        //
//                             Variables                                  //
//                                                                        //
//########################################################################//

var namingConvention = '{wloadname}-{subwloadname}-{rtype}-{env}-{loc}-{seq}'
var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = toLower('${workspaceName}-${sequenceFormatted}-{rtype}-${deploymentTime}')
var namingStructure = toLower(replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workspaceName))

var containerNames = {
  exportApprovedContainerName: 'export-approved'
  ingestContainerName: 'ingest'
  exportPendingContainerName: 'export-pending'
}

// Virtual Network configuration for building a new virtual network for research workspace
var privateEndpointSubnetName = 'privateEndpoints'
var computeSubnetName = 'compute'

// Subnet configuration for building a new virtual network for research workspace
// WATCH OUT: the Bicep items() function will sort the subnets alphabetically by the key
var workspaceSubnets = {
  '10_${privateEndpointSubnetName}': {
    name: privateEndpointSubnetName
    addressPrefix: '172.17.0.0/25'
    privateEndpointNetworkPolicies: 'Enabled'
    serviceEndpoints: []
  }
  '20_${computeSubnetName}': {
    name: computeSubnetName
    addressPrefix: '172.17.0.128/25'
    privateEndpointNetworkPolicies: 'Disabled'
    serviceEndpoints: []
  }
}

var workspaceComputeSubnetNsgRules = [
  // TODO: Create as a JSON content file and load
  {
    name: 'Allow_RDP_From_AVD'
    properties: {
      direction: 'Inbound'
      priority: 200
      protocol: 'TCP'
      access: 'Allow'
      sourceAddressPrefixes: accessVNetAddressPrefixes
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '3389'
    }
  }
  {
    name: 'Block_Internet_Access'
    properties: {
      direction: 'Outbound'
      priority: 4096
      protocol: '*'
      access: 'Deny'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'Internet'
      destinationPortRange: '*'
    }
  }
]
var workspacePepSubnetNsgRules = []

// The Network Security Group rules must be specified 
// in the alphabetical order of the subnet dictionary object's keys
// TODO: Integrate in the definition of the subnets (per https://github.com/SvenAelterman/Bicep-VNetModule)
var workspaceNsgRules = [
  workspacePepSubnetNsgRules
  workspaceComputeSubnetNsgRules
]

//########################################################################//
//                                                                        //
//                             Foundations                                //
//                                                                        //
//########################################################################//

// Get existing log analytics workspace resource group if the logAnalytics object was supplied at deployment
resource existingLogAnalyticsRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(logAnalytics)) {
  name: split(privateStorage.id, '/')[3]
}

// Get existing log analytics workspace if the logAnalytics object was supplied at deployment
#disable-next-line no-unused-existing-resources
resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' existing = if (!empty(logAnalytics)) {
  name: logAnalytics.name
  scope: existingLogAnalyticsRG
}

// Create the log analytics resource group if the logAnalytics object wasn't supplied at deployment
resource sharedWorkspaceRG 'Microsoft.Resources/resourceGroups@2021-04-01' = if (empty(logAnalytics)) {
  name: replace(replace(namingStructure, '{subwloadname}', 'sharedsvc'), '{rtype}', 'rg')
  location: location
  tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
}

// Create the log analytics workspace resource if the logAnalytics object wasn't supplied at deployment
module workspaceLaw '../child_modules/logAnalytics.bicep' = if (empty(logAnalytics)) {
  name: replace(deploymentNameStructure, '{rtype}', 'log')
  scope: sharedWorkspaceRG
  params: {
    namingStructure: namingStructure
    location: location
    tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
  }
}

//##################################################################################################################################################################################

// Create the virtual network resource group if the virtualNetwork object wasn't supplied at deployment
resource newNetworkWorkspaceRG 'Microsoft.Resources/resourceGroups@2021-04-01' = if (empty(virtualNetwork)) {
  name: replace(replace(namingStructure, '{subwloadname}', 'network'), '{rtype}', 'rg')
  location: location
  tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
}

// Create the virtual network if the virtualNetwork object wasn't supplied at deployment
module workspaceVnet '../child_modules/network.bicep' = if (empty(virtualNetwork)) {
  name: replace(deploymentNameStructure, '{rtype}', 'net')
  scope: newNetworkWorkspaceRG
  params: {
    deploymentNameStructure: deploymentNameStructure
    location: location
    namingStructure: namingStructure
    addressPrefixes: workspaceVNetAddressPrefixes
    subnets: workspaceSubnets
    defaultRouteNextHop: defaultRouteNextHop
    hubVirtualNetworkId: hubVirtualNetworkId
    tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
    nsgSecurityRules: workspaceNsgRules
  }
}

// module networkWatcher '../child_modules/networkWatcherRG.bicep' = if (empty(virtualNetwork)) {
//   name: replace(deploymentNameStructure, '{rtype}', 'networkWatcherRG')
//   scope: subscription()
//   params: {
//     location: location
//     tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
//     deploymentNameStructure: deploymentNameStructure
//   }
// }

//##################################################################################################################################################################################

// Get the existing private storage account resource group if the storageAccount object was supplied at deployment
resource existingPrivateStorageRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(privateStorage)) {
  name: split(privateStorage.id, '/')[3]
}

// Get the existing private storage account if the storageAccount object was supplied at deployment
resource existingPrivateStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' existing = if (!empty(privateStorage)) {
  name: privateStorage.name
  scope: existingPrivateStorageRG
}

// Create the storage resource group if the storageAccount object wasn't supplied at deployment
resource newDataWorkspaceRG 'Microsoft.Resources/resourceGroups@2021-04-01' = if (empty(privateStorage)) {
  name: replace(replace(namingStructure, '{subwloadname}', 'storage'), '{rtype}', 'rg')
  location: location
  tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
}

// Create the private storage account if the storageAccount object wasn't supplied at deployment
module newPrivateStorageAccount '../child_modules/storage_account.bicep' = if (empty(privateStorage)) {
  name: replace(deploymentNameStructure, '{rtype}', 'stg-pri')
  scope: newDataWorkspaceRG
  params: {
    location: location
    namingStructure: namingStructure
    subwloadname: 'pri'
    containerNames: [
      containerNames.exportApprovedContainerName
      containerNames.exportPendingContainerName
    ]
    // The private storage account must be integrated with a VNet
    vnetId: empty(virtualNetwork) ? workspaceVnet.outputs.vNetId : virtualNetwork.id
    subnetId: empty(virtualNetwork) ? workspaceVnet.outputs.subnetIds[0] : existingPrivateEndpointSubnetId
    privatize: true
    tags: empty(tags) ? {} : (empty(tags.Core) ? {} : tags.Core)
  }
}

//########################################################################//
//                                                                        //
//                                Modules                                 //
//                                                                        //
//########################################################################//

// DATA AUTOMATION MODULE
// TODO: Add a switch to enable or disable
module dataAutomation './dataAutomation.bicep' = {
  name: 'data-automation-${deploymentTime}'
  params: {
    location: location
    workspaceName: workspaceName
    namingStructure: namingStructure
    deploymentNameStructure: deploymentNameStructure
    containerNames: containerNames
    pipelineName: pipelineName
    privateStorageAccountName: empty(privateStorage) ? newPrivateStorageAccount.outputs.storageAccountName : existingPrivateStorageAccount.name
    privateStorageAccountRG: empty(privateStorage) ? newDataWorkspaceRG.name : existingPrivateStorageRG.name
    approverEmail: approverEmail
    userAssignedManagedIdentity: userAssignedManagedIdentity
    tags: empty(tags) ? {} : (empty(tags['Data Automation']) ? {} : tags['Data Automation'])
  }
}

// REMOTE ACCESS MODULE (AVD)
module access './access.bicep' = if (avdAccess) {
  name: 'access-${deploymentTime}'
  params: {
    location: location
    namingStructure: namingStructure
    subwloadname: 'access'
    deploymentNameStructure: deploymentNameStructure
    vmCount: vmCount
    rdshVmSize: rdshVmSize
    vnetAddressPrefixes: accessVNetAddressPrefixes
    workspaceVNet: workspaceVnet.outputs.vNet
    rdshPrefix: 'rdsh'
    tags: empty(tags) ? {} : (empty(tags['Remote Access']) ? {} : tags['Remote Access'])
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
  }
}
