// DDoS protection plan — deployable through Azure Verified Module avm/res/network/ddos-protection-plan 0.3.2
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('DDoS protection plan instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/network/ddos-protection-plan:0.3.2' = [for (instance, index) in instances: {
  name: take('avm-ddos-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: location
    tags: tags
    enableTelemetry: false


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

module identityRoles 'ddos-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-ddos-${index}-${assignment.targetName}', 64)
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
