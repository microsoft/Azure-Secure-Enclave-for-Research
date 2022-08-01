targetScope = 'subscription'

param location string
param namingStructure string
param subwloadname string = ''
param deploymentNameStructure string
param avdSubnetId string
param rdshVmSize string
param rdshPrefix string
param vmCount int
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

// If needed, create a separate resource group for the VMs
resource avdResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(baseName, '{rtype}', 'rg')
  location: location
  tags: tags
}

module avd '../child_modules/avd.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd')
  scope: avdResourceGroup
  params: {
    namingStructure: namingStructure
    location: location
    tags: tags
  }
}

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
    avdSubnetId: avdSubnetId
    tags: tags
  }
}
