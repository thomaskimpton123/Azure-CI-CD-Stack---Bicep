// Virtual Network peerings — validated deployable composition
targetScope = 'resourceGroup'

type peeringConfigType = {
  remoteVnetName: string
  remoteResourceGroup: string
  remoteSubscriptionId: string?
  allowForwardedTraffic: bool
  allowGatewayTransit: bool?
  useRemoteGateways: bool?
}

type serviceConfigType = {
  resourceName: string
  peerings: peeringConfigType[]?
}

@description('Virtual Network instances whose peerings are created in this resource group.')
param instances serviceConfigType[] = []

var links = flatten(map(instances, instance => map(instance.?peerings ?? [], peering => {
  localVnetName: instance.resourceName
  remoteVnetName: peering.remoteVnetName
  remoteResourceGroup: peering.remoteResourceGroup
  remoteSubscriptionId: peering.?remoteSubscriptionId
  allowForwardedTraffic: peering.allowForwardedTraffic
  allowGatewayTransit: peering.?allowGatewayTransit ?? false
  useRemoteGateways: peering.?useRemoteGateways ?? false
})))

resource peerings 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-07-01' = [for link in links: {
  name: '${link.localVnetName}/${take('peer-${link.remoteVnetName}', 80)}'
  properties: {
    remoteVirtualNetwork: {
      id: resourceId(link.?remoteSubscriptionId ?? subscription().subscriptionId, link.remoteResourceGroup, 'Microsoft.Network/virtualNetworks', link.remoteVnetName)
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: link.allowForwardedTraffic
    // The hub shares its VPN/ExpressRoute gateway; spokes use it. Runs after the gateways exist.
    allowGatewayTransit: link.allowGatewayTransit
    useRemoteGateways: link.useRemoteGateways
  }
}]
