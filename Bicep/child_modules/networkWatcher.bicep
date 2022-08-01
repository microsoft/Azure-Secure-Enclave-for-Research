param location string

resource networkWatcher 'Microsoft.Network/networkWatchers@2021-05-01' = {
  name: 'NetworkWatcher_${location}'
  location: location
}
