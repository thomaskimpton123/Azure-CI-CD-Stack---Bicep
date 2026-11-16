// Virtual Network — validated deployable composition — through Azure Verified Module avm/res/network/virtual-network 0.10.2, avm/res/network/bastion-host 0.8.2
targetScope = 'resourceGroup'

type subnetConfigType = {
  name: string
  cidr: string
  ipv4Range: string?
}

type delegationConfigType = {
  subnet: string
  service: string
}

type subnetNsgType = {
  subnet: string
  nsgName: string
  nsgResourceGroup: string
}

type subnetAttachmentType = {
  subnet: string
  name: string
  resourceGroup: string
}

type peeringConfigType = {
  remoteVnetName: string
  remoteResourceGroup: string
  remoteSubscriptionId: string?
  allowForwardedTraffic: bool
  allowGatewayTransit: bool?
  useRemoteGateways: bool?
}

type serviceConfigType = {
  resourceName: string?
  subscriptionRef: string?
  resourceGroupRef: string?
  addressSpaces: string[]?
  subnets: subnetConfigType[]?
  vnetEncryption: bool?
  deployBastion: bool?
  ddosNetworkProtection: bool?
  ddosPlanId: string?
  ddosPlanName: string?
  ddosPlanResourceGroup: string?
  ddosPlanSubscriptionId: string?
  subnetDelegations: delegationConfigType[]?
  subnetNsgs: subnetNsgType[]?
  subnetRouteTables: subnetAttachmentType[]?
  subnetNatGateways: subnetAttachmentType[]?
  dnsServers: string[]?
  peerings: peeringConfigType[]?
  serviceEndpoints: string[]?
  defaultOutboundAccess: bool?
}

@description('Virtual Network instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

// Azure-managed subnets: no service endpoints are added to these.
var reservedSubnetNames = ['GatewaySubnet', 'AzureFirewallSubnet', 'AzureFirewallManagementSubnet', 'AzureBastionSubnet', 'RouteServerSubnet']

var resolvedInstances = [for (instance, index) in instances: {
  name: empty(instance.?resourceName ?? '') ? 'vnet-${uniqueString(resourceGroup().id, string(index))}' : (instance.?resourceName ?? '')
  addressSpaces: instance.?addressSpaces ?? ['10.0.0.0/16']
  subnets: instance.?subnets ?? []
  vnetEncryption: instance.?vnetEncryption ?? false
  deployBastion: instance.?deployBastion ?? false
  ddosPlanId: !(instance.?ddosNetworkProtection ?? false) ? '' : empty(instance.?ddosPlanName ?? '') ? (instance.?ddosPlanId ?? '') : resourceId(instance.?ddosPlanSubscriptionId ?? subscription().subscriptionId, instance.?ddosPlanResourceGroup ?? '', 'Microsoft.Network/ddosProtectionPlans', instance.?ddosPlanName ?? '')
  subnetDelegations: instance.?subnetDelegations ?? []
  // NSGs are attached here, inside the subnet definition, so redeploying the VNet keeps them.
  nsgIdsBySubnet: toObject(instance.?subnetNsgs ?? [], link => link.subnet, link => resourceId(link.?nsgSubscriptionId ?? subscription().subscriptionId, link.nsgResourceGroup, 'Microsoft.Network/networkSecurityGroups', link.nsgName))
  routeTableIdsBySubnet: toObject(instance.?subnetRouteTables ?? [], link => link.subnet, link => resourceId(link.?subscriptionId ?? subscription().subscriptionId, link.resourceGroup, 'Microsoft.Network/routeTables', link.name))
  natGatewayIdsBySubnet: toObject(instance.?subnetNatGateways ?? [], link => link.subnet, link => resourceId(link.?subscriptionId ?? subscription().subscriptionId, link.resourceGroup, 'Microsoft.Network/natGateways', link.name))
  dnsServers: instance.?dnsServers ?? []
  serviceEndpoints: instance.?serviceEndpoints ?? []
  defaultOutboundAccess: instance.?defaultOutboundAccess ?? false
}]

module virtualNetworks 'br/public:avm/res/network/virtual-network:0.10.2' = [for (instance, index) in resolvedInstances: {
  name: take('avm-vnet-${instance.name}', 64)
  params: {
    name: instance.name
    location: location
    tags: tags
    enableTelemetry: false
    addressPrefixes: instance.addressSpaces
    dnsServers: instance.dnsServers
    // Links the DDoS Protection tile's plan, or an existing plan by resource ID.
    ddosProtectionPlanResourceId: empty(instance.ddosPlanId) ? null : instance.ddosPlanId
    vnetEncryption: instance.vnetEncryption
    vnetEncryptionEnforcement: 'AllowUnencrypted'
    // NSGs, route tables and NAT gateways are attached inside each subnet, so redeploying the VNet keeps them.
    subnets: map(instance.subnets, subnet => {
      name: subnet.name
      addressPrefix: subnet.cidr
      defaultOutboundAccess: instance.defaultOutboundAccess
      delegation: first(map(filter(instance.subnetDelegations, item => item.subnet == subnet.name), delegation => delegation.service))
      networkSecurityGroupResourceId: instance.nsgIdsBySubnet[?subnet.name]
      routeTableResourceId: instance.routeTableIdsBySubnet[?subnet.name]
      natGatewayResourceId: instance.natGatewayIdsBySubnet[?subnet.name]
      serviceEndpoints: contains(reservedSubnetNames, subnet.name) ? [] : instance.serviceEndpoints
    })
  }
}]

module bastionHosts 'br/public:avm/res/network/bastion-host:0.8.2' = [for (instance, index) in resolvedInstances: if (instance.deployBastion) {
  name: take('avm-bas-${instance.name}', 64)
  params: {
    name: take('bas-${instance.name}', 80)
    location: location
    tags: tags
    enableTelemetry: false
    virtualNetworkResourceId: virtualNetworks[index].outputs.resourceId
    // Standard SKU: the module turns native-client tunnelling on itself (it has no enableTunneling input).
    skuName: 'Standard'
    enableIpConnect: true
    publicIPAddressObject: {
      name: take('pip-bas-${instance.name}', 80)
    }
  }
}]

output configurations serviceConfigType[] = instances
