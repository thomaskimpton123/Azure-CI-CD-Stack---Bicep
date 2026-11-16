// DNS private resolver — deployable through Azure Verified Module avm/res/network/dns-resolver 0.5.8
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('DNS private resolver instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/network/dns-resolver:0.5.8' = [for (instance, index) in instances: {
  name: take('avm-dnspr-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: location
    tags: tags
    enableTelemetry: false
    virtualNetworkResourceId: resourceId(instance.deploy.vnet.?subscriptionId ?? subscription().subscriptionId, instance.deploy.vnet.?resourceGroup ?? '', 'Microsoft.Network/virtualNetworks', instance.deploy.vnet.?name ?? '')
    inboundEndpoints: [
      {
        name: 'inbound'
        subnetResourceId: resourceId(instance.deploy.inboundSubnet.?vnetSubscriptionId ?? subscription().subscriptionId, instance.deploy.inboundSubnet.?vnetResourceGroup ?? '', 'Microsoft.Network/virtualNetworks/subnets', instance.deploy.inboundSubnet.?vnetRef ?? '', instance.deploy.inboundSubnet.?subnetRef ?? '')
      }
    ]
    outboundEndpoints: [
      {
        name: 'outbound'
        subnetResourceId: resourceId(instance.deploy.outboundSubnet.?vnetSubscriptionId ?? subscription().subscriptionId, instance.deploy.outboundSubnet.?vnetResourceGroup ?? '', 'Microsoft.Network/virtualNetworks/subnets', instance.deploy.outboundSubnet.?vnetRef ?? '', instance.deploy.outboundSubnet.?subnetRef ?? '')
      }
    ]
    roleAssignments: map(filter(instance.deploy.roleAssignments, assignment => !empty(assignment.principalId)), assignment => {
      roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleId)
      principalId: assignment.principalId
    })
  }
}]

module rulesets 'br/public:avm/res/network/dns-forwarding-ruleset:0.5.4' = [for (instance, index) in instances: if (!empty(instance.deploy.forwardingRules)) {
  name: take('avm-dnsfrs-${instance.resourceName}', 64)
  params: {
    name: 'dnsfrs-${instance.resourceName}'
    location: location
    tags: tags
    enableTelemetry: false
    dnsForwardingRulesetOutboundEndpointResourceIds: [
      resourceId('Microsoft.Network/dnsResolvers/outboundEndpoints', instance.resourceName, 'outbound')
    ]
    forwardingRules: map(instance.deploy.forwardingRules, rule => {
      name: rule.name
      domainName: rule.domainName
      forwardingRuleState: rule.state
      targetDnsServers: [
        {
          ipAddress: rule.ipAddress
          port: rule.port
        }
      ]
    })
    virtualNetworkLinks: map(instance.deploy.rulesetVnetLinks, link => {
      name: take('link-${link.name}', 80)
      virtualNetworkResourceId: resourceId(link.?subscriptionId ?? subscription().subscriptionId, link.resourceGroup, 'Microsoft.Network/virtualNetworks', link.name)
    })
  }
  dependsOn: [resources]
}]

var identityRoleAssignments = flatten(map(instances, instance => map(filter(instance.deploy.roleAssignments, assignment => empty(assignment.principalId)), assignment => {
  targetName: instance.resourceName
  roleId: assignment.roleId
  dataPlane: assignment.dataPlane
  identityName: assignment.identityName
  identityResourceGroup: assignment.identityResourceGroup
  identitySubscriptionId: assignment.?identitySubscriptionId ?? subscription().subscriptionId
})))

module identityRoles 'dns-private-resolver-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-dnspr-${index}-${assignment.targetName}', 64)
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
