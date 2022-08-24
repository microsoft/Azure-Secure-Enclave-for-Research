param location string
param namingStructure string
param arguments string
param scriptContent string
param userAssignedIdentityId string

param subwloadname string = ''
param tags object = {}
param currentTime string = utcNow()

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: replace(baseName, '{rtype}', 'dplscr')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.4'
    timeout: 'PT10M'
    arguments: arguments
    scriptContent: scriptContent
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: currentTime
  }
  tags: tags
}
