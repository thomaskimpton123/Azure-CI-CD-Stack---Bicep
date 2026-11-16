// Network Watcher — deployable through Azure Verified Module avm/res/network/network-watcher 0.5.1
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('Network Watcher instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/network/network-watcher:0.5.1' = [for (instance, index) in instances: {
  name: take('avm-nw-${instance.resourceName}', 64)
  params: {
    name: 'NetworkWatcher_${location}'
    location: location
    tags: tags
    enableTelemetry: false
    flowLogs: map(instance.deploy.flowLogs, log => {
      name: log.name
      targetResourceId: resourceId(log.vnet.?subscriptionId ?? subscription().subscriptionId, log.vnet.?resourceGroup ?? '', 'Microsoft.Network/virtualNetworks', log.vnet.?name ?? '')
      storageResourceId: resourceId(log.storage.?subscriptionId ?? subscription().subscriptionId, log.storage.resourceGroup, 'Microsoft.Storage/storageAccounts', log.storage.name)
      enabled: true
      formatVersion: 2
      retentionInDays: log.retentionDays
      workspaceResourceId: empty(log.?workspace.?name ?? '') ? '' : resourceId(log.?workspace.?subscriptionId ?? subscription().subscriptionId, log.?workspace.?resourceGroup ?? '', 'Microsoft.OperationalInsights/workspaces', log.?workspace.?name ?? '')
      trafficAnalyticsInterval: log.trafficAnalyticsInterval
    })

  }
}]

var identityRoleAssignments = flatten(map(instances, instance => map(filter(instance.deploy.roleAssignments, assignment => empty(assignment.principalId)), assignment => {
  targetName: instance.resourceName
  roleId: assignment.roleId
  dataPlane: assignment.dataPlane
  identityName: assignment.identityName
  identityResourceGroup: assignment.identityResourceGroup
  identitySubscriptionId: assignment.?identitySubscriptionId ?? subscription().subscriptionId
})))

module identityRoles 'network-watcher-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-nw-${index}-${assignment.targetName}', 64)
  params: {
    targetName: assignment.targetName
    roleId: assignment.roleId
    identityName: assignment.identityName
    identityResourceGroup: assignment.identityResourceGroup
    identitySubscriptionId: assignment.?identitySubscriptionId ?? subscription().subscriptionId
  }
  dependsOn: [resources]
}]

output configurations serviceConfigType[] = instances
