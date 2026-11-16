// Route tables — validated deployable composition (attached to subnets in modules/vnet.bicep) — through Azure Verified Module avm/res/network/route-table 0.5.0
targetScope = 'resourceGroup'

type routeType = {
  name: string
  addressPrefix: string
  nextHopType: ('VirtualAppliance' | 'VirtualNetworkGateway' | 'Internet' | 'None')
  nextHopIpAddress: string?
}

type serviceConfigType = {
  resourceName: string
  disableBgpRoutePropagation: bool?
  routes: routeType[]?
}

@description('Route table instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module routeTables 'br/public:avm/res/network/route-table:0.5.0' = [for instance in instances: {
  name: take('avm-rt-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: location
    tags: tags
    enableTelemetry: false
    disableBgpRoutePropagation: instance.?disableBgpRoutePropagation ?? false
    routes: map(instance.?routes ?? [], route => {
      name: route.name
      properties: union({
        addressPrefix: route.addressPrefix
        nextHopType: route.nextHopType
      }, route.nextHopType == 'VirtualAppliance' ? {
        nextHopIpAddress: route.?nextHopIpAddress ?? ''
      } : {})
    })
  }
}]

output configurations serviceConfigType[] = instances
