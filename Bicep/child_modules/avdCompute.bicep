param location string
param rdshPrefix string
param avdSubnetId string
param rdshVmSize string
param hostPoolRegistrationToken string
param hostPoolName string
param vmCount int = 1
param deploymentNameStructure string = '{rtype}-${utcNow()}'
param tags object = {}

// Use the same VM templates as used by the Add VM to hostpool process
var nestedTemplatesLocation = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/armtemplates/Hostpool_12-9-2021/nestedTemplates/'
var vmTemplateUri = '${nestedTemplatesLocation}managedDisks-galleryvm.json'

// Create availability set
resource availabilitySet 'Microsoft.Compute/availabilitySets@2021-11-01' = {
  name: '${rdshPrefix}-avail'
  location: location
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
  sku: {
    name: 'Aligned'
  }
  tags: tags
}

// Deploy the session host VMs just like the Add VM to hostpool process would
resource vmDeployment 'Microsoft.Resources/deployments@2021-04-01' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avdvm')
  properties: {
    mode: 'Incremental'
    templateLink: {
      uri: vmTemplateUri
      contentVersion: '1.0.0.0'
    }
    parameters: {
      artifactsLocation: {
        value: 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_02-23-2022.zip'
      }
      availabilityOption: {
        value: 'AvailabilitySet'
      }
      availabilitySetName: {
        value: availabilitySet.name
      }
      vmGalleryImageOffer: {
        value: 'office-365'
      }
      vmGalleryImagePublisher: {
        value: 'microsoftwindowsdesktop'
      }
      vmGalleryImageHasPlan: {
        value: false
      }
      vmGalleryImageSKU: {
        value: 'win11-21h2-avd-m365'
      }
      rdshPrefix: {
        value: rdshPrefix
      }
      rdshNumberOfInstances: {
        value: vmCount
      }
      rdshVMDiskType: {
        value: 'StandardSSD_LRS'
      }
      rdshVmSize: {
        value: rdshVmSize
      }
      enableAcceleratedNetworking: {
        value: true
      }
      vmAdministratorAccountUsername: {
        value: 'AzureUser'
      }
      vmAdministratorAccountPassword: {
        value: 'Test1234'
      }
      administratorAccountUsername: {
        value: ''
      }
      administratorAccountPassword: {
        value: ''
      }
      'subnet-id': {
        value: avdSubnetId
      }
      vhds: {
        value: 'vhds/${rdshPrefix}'
      }
      location: {
        value: location
      }
      createNetworkSecurityGroup: {
        value: false
      }
      vmInitialNumber: {
        value: 0
      }
      hostpoolName: {
        value: hostPoolName
      }
      hostpoolToken: {
        value: hostPoolRegistrationToken
      }
      aadJoin: {
        value: true
      }
      intune: {
        value: false
      }
      securityType: {
        value: 'TrustedLaunch'
      }
      secureBoot: {
        value: true
      }
      vTPM: {
        value: true
      }
      vmImageVhdUri: {
        value: ''
      }
    }
  }
}
