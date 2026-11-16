// Grants one built-in role on a Private DNS zone to a user-assigned managed identity.
targetScope = 'resourceGroup'

@description('Name of the Private DNS zone in this resource group.')
param targetName string

@description('Built-in role definition GUID.')
param roleId string

@description('User-assigned managed identity that receives the role.')
param identityName string

@description('Resource group of the managed identity.')
param identityResourceGroup string

@description('Subscription of the managed identity.')
param identitySubscriptionId string = subscription().subscriptionId

resource target 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: targetName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: identityName
  scope: resourceGroup(identitySubscriptionId, identityResourceGroup)
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(target.id, identity.id, roleId)
  scope: target
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
