param location string
param namingStructure string
param roles object

param subwloadname string = ''
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

// Create a new User Assigned Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: replace(baseName, '{rtype}', 'uami')
  location: location
  tags: tags
}

// Assign roles to the uami for post deployment tasks
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for r in items(roles): {
  name: guid('rbac-${managedIdentity.name}-${r.key}')
  properties: {
    roleDefinitionId: r.value
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

output managedIdentityId string = managedIdentity.id
