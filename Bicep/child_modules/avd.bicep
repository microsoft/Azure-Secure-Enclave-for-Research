param location string
param environment string = ''
param namingStructure string
param subwloadname string = ''
param baseTime string = utcNow('u')
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

// create hostpool for avd VMs
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2021-09-03-preview' = {
  name: replace(baseName, '{rtype}', 'hp')
  location: location
  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    preferredAppGroupType: 'RailApplications'
    customRdpProperty: 'drivestoredirect:s:0;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:0;redirectprinters:i:0;devicestoredirect:s:0;redirectcomports:i:0;redirectsmartcards:i:1;usbdevicestoredirect:s:0;enablecredsspsupport:i:1;use multimon:i:1;targetisaadjoined:i:1;'
    friendlyName: '${environment} Research Enclave Access'
    startVMOnConnect: true
    registrationInfo: {
      registrationTokenOperation: 'Update'
      // Expire the new registration token in two days
      expirationTime: dateTimeAdd(baseTime, 'P2D')
    }
  }
  tags: tags
}

// setup remote application group for remote apps
resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2021-09-03-preview' = {
  name: replace(baseName, '{rtype}', 'ag')
  location: location
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'RemoteApp'
  }
  tags: tags
}

// setup rdp as remote app in app group
resource app 'Microsoft.DesktopVirtualization/applicationGroups/applications@2021-09-03-preview' = {
  name: 'Remote Desktop'
  parent: applicationGroup
  properties: {
    commandLineSetting: 'DoNotAllow'
    applicationType: 'InBuilt'
    friendlyName: 'Remote Desktop'
    filePath: 'C:\\Windows\\System32\\mstsc.exe'
    iconPath: 'C:\\Windows\\System32\\mstsc.exe'
    iconIndex: 0
    showInPortal: true
  }
}

// create workspace for AVD app groups
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-09-03-preview' = {
  name: replace(baseName, '{rtype}', 'ws')
  location: location
  properties: {
    friendlyName: 'Research Enclave Access'
    applicationGroupReferences: [
      applicationGroup.id
    ]
  }
  tags: tags
}

output hostpoolRegistrationToken string = hostPool.properties.registrationInfo.token
output hostpoolName string = hostPool.name
