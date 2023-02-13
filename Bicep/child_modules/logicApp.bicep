param location string
param namingStructure string
param adfName string
param pipelineName string
param storageAcctName string
param approverEmail string

param subwloadname string = ''
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

resource storageAcct 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAcctName
}

resource adf 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: adfName
}

resource adfConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'api-${adfName}'
  location: location
  // kind is a valid property
  #disable-next-line BCP187
  kind: 'V1'
  properties: {
    displayName: adfName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuredatafactory')
    }
    //parameterValueType: 'Alternative'
  }
  tags: tags
}

resource stgConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'api-${storageAcctName}'
  location: location
  // kind is a valid property
  #disable-next-line BCP187
  kind: 'V1'
  properties: {
    displayName: storageAcctName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    // This appears to be valid and working to set the authentication property for this connection
    #disable-next-line BCP089
    parameterValueSet: {
      name: 'managedIdentityAuth'
      value: {}
    }
  }
  tags: tags
}

resource emailConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'api-office365'
  location: location
  // kind is a valid property
  #disable-next-line BCP187
  kind: 'V1'
  properties: {
    displayName: 'office365'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
  tags: tags
}

// logic app
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: replace(baseName, '{rtype}', 'logic')
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    definition: json(loadTextContent('../content/logicAppWorkflow.json'))
    parameters: {
      '$connections': {
        value: {
          azureblob: {
            connectionId: stgConnection.id
            connectionName: 'azureblob'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          azuredatafactory: {
            connectionId: adfConnection.id
            connectionName: 'azuredatafactory'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuredatafactory')
          }
          office365: {
            connectionId: emailConnection.id
            connectionName: 'office365'
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
      subscriptionId: {
        value: subscription().subscriptionId
      }
      dataFactoryRG: {
        value: resourceGroup().name
      }
      dataFactoryName: {
        value: adf.name
      }
      pipelineName: {
        value: pipelineName
      }
      storageAccountName: {
        value: storageAcctName
      }
      approverEmail: {
        value: approverEmail
      }
    }
  }
  tags: tags
}

// set rbac on adf for logicApp
resource logicAppAdfRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('rbac-${adf.name}-adf')
  scope: adf
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '673868aa-7521-48a0-acc6-0f60742d39f5')
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// set rbac on stg account for LogicApp
resource logicAppPrivateStgRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('rbac-${storageAcct.name}-logicapp')
  scope: storageAcct
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
