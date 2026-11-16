// Resource Group Locks — governance applied at resource-group scope
targetScope = 'resourceGroup'

@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param level string

param notes string = 'Managed by the Azure infrastructure pack'

resource resourceGroupLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'infrastructure-protection'
  properties: {
    level: level
    notes: notes
  }
}
