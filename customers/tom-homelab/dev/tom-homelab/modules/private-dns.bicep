// Private DNS zone — deployable through Azure Verified Module avm/res/network/private-dns-zone 0.8.1
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('Private DNS zone instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
#disable-next-line no-unused-params
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/network/private-dns-zone:0.8.1' = [for (instance, index) in flatten(map(instances, instance => instance.deploy.zones)): {
  name: take('avm-pdns-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: 'global'
    tags: tags
    enableTelemetry: false
    a: instance.deploy.a
    aaaa: instance.deploy.aaaa
    cname: instance.deploy.cname
    txt: instance.deploy.txt
    ptr: instance.deploy.ptr
    srv: instance.deploy.srv
    // Named like the private endpoint zones module's links, so a zone both create keeps one link per VNet.
    virtualNetworkLinks: map(instance.deploy.links, link => {
      name: 'link-${uniqueString(resourceId(link.?subscriptionId ?? subscription().subscriptionId, link.?resourceGroup ?? '', 'Microsoft.Network/virtualNetworks', link.?name ?? ''))}'
      virtualNetworkResourceId: resourceId(link.?subscriptionId ?? subscription().subscriptionId, link.?resourceGroup ?? '', 'Microsoft.Network/virtualNetworks', link.?name ?? '')
      registrationEnabled: link.registrationEnabled
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

module identityRoles 'private-dns-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-pdns-${index}-${assignment.targetName}', 64)
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
