// Bastion host — deployable through Azure Verified Module avm/res/network/bastion-host 0.8.2
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('Bastion host instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/network/bastion-host:0.8.2' = [for (instance, index) in instances: {
  name: take('avm-bas-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: location
    tags: tags
    enableTelemetry: false
    virtualNetworkResourceId: resourceId(instance.deploy.vnet.?subscriptionId ?? subscription().subscriptionId, instance.deploy.vnet.?resourceGroup ?? '', 'Microsoft.Network/virtualNetworks', instance.deploy.vnet.?name ?? '')
    skuName: instance.deploy.sku
    availabilityZones: instance.deploy.zones
    scaleUnits: instance.deploy.scaleUnits
    enableIpConnect: instance.deploy.ipConnect
    enableKerberos: instance.deploy.kerberos
    enableShareableLink: instance.deploy.shareableLink
    enableSessionRecording: instance.deploy.sessionRecording
    publicIPAddressObject: {
      name: 'pip-${instance.resourceName}'
      availabilityZones: instance.deploy.zones
    }
    diagnosticSettings: map(instance.deploy.diagnosticWorkspaces, workspace => {
      workspaceResourceId: resourceId(workspace.?subscriptionId ?? subscription().subscriptionId, workspace.resourceGroup, 'Microsoft.OperationalInsights/workspaces', workspace.name)
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

module identityRoles 'bastion-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-bas-${index}-${assignment.targetName}', 64)
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
