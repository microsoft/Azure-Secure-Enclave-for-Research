param storageAccountId string
param sinkStorageAccountName string
param sourceStorageAccountName string
param adfName string
param ingestPipelineName string
param workspaceName string

@allowed([
  'Public'
  'Private'
])
param storageAccountType string

param containerName string = ''

resource trigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${adfName}/trigger_ws_${workspaceName}_${storageAccountType}_BlobCreated'
  properties: {
    type: 'BlobEventsTrigger'
    typeProperties: {
      // No blobPathBeginsWith property means all containers will be matched (used for ingest)
      blobPathBeginsWith: !empty(containerName) ? '/${containerName}/blobs/' : json('null')
      ignoreEmptyBlobs: true
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
      scope: storageAccountId
    }
    pipelines: [
      {
        pipelineReference: {
          referenceName: ingestPipelineName
          type: 'PipelineReference'
        }
        parameters: {
          sourceStorageAccountName: sourceStorageAccountName
          sinkStorageAccountName: sinkStorageAccountName
          fileName: '@triggerBody().fileName'
          sourceFolderPath: '@triggerBody().folderPath'
          sinkFolderPath: '@triggerBody().folderPath'
        }
      }
    ]
  }
}
