param location string
param namingStructure string
param deploymentNameStructure string
param subwloadname string = ''
param pipelineName string
param privateStorageAcctName string
param userAssignedIdentityId string
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')
var managedVnetName = 'default'
var autoResolveIntegrationRuntimeName = 'AutoResolveIntegrationRuntime'
var linkedServiceName = 'ls_ADLSGen2_Generic'

resource privateStorageAcct 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: privateStorageAcctName
}

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: replace(baseName, '{rtype}', 'adf')
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
}

// Deployment script to stop any existing triggers on the ADF
module deploymentScript '../child_modules/deploymentScript.bicep' = {
  name: 'StopTrigger-${replace(deploymentNameStructure, '{rtype}', 'dplscr')}'
  params: {
    location: location
    subwloadname: 'StopTriggers'
    namingStructure: namingStructure
    arguments: ' -ResourceGroupName ${resourceGroup().name} -azureDataFactoryName ${adf.name}'
    scriptContent: '\r\n          param(\r\n            [string] [Parameter(Mandatory=$true)] $ResourceGroupName,\r\n            [string] [Parameter(Mandatory=$true)] $azureDataFactoryName\r\n            )\r\n\r\n          Connect-AzAccount -Identity\r\n\r\n          # Stop Triggers\r\n          Get-AzDataFactoryV2Trigger -DataFactoryName $azureDataFactoryName -ResourceGroupName $ResourceGroupName | Where-Object { $_.RuntimeState -eq \'Started\' } | Stop-AzDataFactoryV2Trigger -Force | Out-Null\r\n'
    userAssignedIdentityId: userAssignedIdentityId
  }
}

resource managedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: '${adf.name}/${managedVnetName}'
  properties: {}
}

resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: '${adf.name}/${autoResolveIntegrationRuntimeName}'
  dependsOn: [
    managedVnet
  ]
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      type: 'ManagedVirtualNetworkReference'
      referenceName: managedVnetName
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

resource genericLinkedServiceAdlsGen2 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${adf.name}/${linkedServiceName}'
  dependsOn: [
    integrationRuntime
  ]
  properties: {
    type: 'AzureBlobFS'
    typeProperties: {
      url: '@{concat(\'https://\', linkedService().storageAccountName, \'.dfs.${environment().suffixes.storage}\')}'
    }
    connectVia: {
      referenceName: autoResolveIntegrationRuntimeName
      type: 'IntegrationRuntimeReference'
    }
    parameters: {
      storageAccountName: {
        type: 'String'
      }
    }
  }
}

resource dfsDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${adf.name}/DfsDataset'
  properties: {
    type: 'Binary'
    linkedServiceName: {
      referenceName: linkedServiceName
      type: 'LinkedServiceReference'
      parameters: {
        storageAccountName: {
          value: '@dataset().storageAccountName'
          type: 'Expression'
        }
      }
    }
    parameters: {
      storageAccountName: {
        type: 'String'
      }
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@dataset().fileName'
          type: 'Expression'
        }
        fileSystem: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
      }
    }
  }
  dependsOn: [
    genericLinkedServiceAdlsGen2
  ]
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${adf.name}/${pipelineName}'
  properties: {
    activities: [
      json(loadTextContent('../content/adfPipeline.json'))
    ]
    parameters: {
      sourceStorageAccountName: {
        type: 'String'
      }
      sinkStorageAccountName: {
        type: 'String'
      }
      sourceFolderPath: {
        type: 'String'
      }
      sinkFolderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
  }
  dependsOn: [
    dfsDataset
  ]
}

resource adfPrivateStgRole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${privateStorageAcct.name}-adf')
  scope: privateStorageAcct
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: adf.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output principalId string = adf.identity.principalId
output name string = adf.name
output managedVNetName string = managedVnet.name
