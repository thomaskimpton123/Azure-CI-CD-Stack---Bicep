// Log Analytics workspace — deployable through Azure Verified Module avm/res/operational-insights/workspace 0.16.1
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('Log Analytics workspace instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/operational-insights/workspace:0.16.1' = [for (instance, index) in instances: {
  name: take('avm-law-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: location
    tags: tags
    enableTelemetry: false
    skuName: instance.deploy.skuName
    skuCapacityReservationLevel: instance.deploy.skuCapacityReservationLevel
    dataRetention: instance.deploy.dataRetention
    dailyQuotaGb: instance.deploy.dailyQuotaGb
    publicNetworkAccessForIngestion: instance.deploy.publicIngestion ? 'Enabled' : 'Disabled'
    publicNetworkAccessForQuery: instance.deploy.publicQuery ? 'Enabled' : 'Disabled'
    forceCmkForQuery: false
    features: {
      enableLogAccessUsingOnlyResourcePermissions: instance.deploy.resourceContextAccess
    }
    roleAssignments: map(filter(instance.deploy.roleAssignments, assignment => !empty(assignment.principalId)), assignment => {
      roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleId)
      principalId: assignment.principalId
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

module identityRoles 'log-analytics-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-law-${index}-${assignment.targetName}', 64)
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
