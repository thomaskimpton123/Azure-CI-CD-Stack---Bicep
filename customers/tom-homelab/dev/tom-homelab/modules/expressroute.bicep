// ExpressRoute circuit and gateway — validated deployable composition
// The gateway-to-circuit connection is made after the provider has provisioned the circuit.
targetScope = 'resourceGroup'

type subnetReferenceType = {
  vnetRef: string
  vnetResourceGroup: string
  vnetSubscriptionId: string?
  subnetRef: string
}

type serviceConfigType = {
  resourceName: string
  serviceProvider: string?
  peeringLocation: string?
  bandwidthMbps: string?
  skuTier: ('Standard' | 'Premium' | 'Local')?
  billingModel: ('MeteredData' | 'UnlimitedData')?
  deployCircuit: bool?
  gatewaySku: string?
  gatewaySubnetRef: subnetReferenceType?
}

@description('ExpressRoute instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

var resolvedInstances = [for instance in instances: {
  name: instance.resourceName
  deployCircuit: instance.?deployCircuit ?? true
  tier: instance.?skuTier ?? 'Premium'
  family: instance.?billingModel ?? 'MeteredData'
  bandwidth: int(instance.?bandwidthMbps ?? '1000')
  provider: instance.?serviceProvider ?? ''
  peeringLocation: instance.?peeringLocation ?? ''
  gatewaySku: instance.?gatewaySku ?? 'ErGw2AZ'
  gatewayName: take('ergw-${instance.resourceName}', 80)
  subnetId: empty(instance.?gatewaySubnetRef.?subnetRef ?? '') ? '' : resourceId(instance.?gatewaySubnetRef.?vnetSubscriptionId ?? subscription().subscriptionId, instance.?gatewaySubnetRef.?vnetResourceGroup ?? '', 'Microsoft.Network/virtualNetworks/subnets', instance.?gatewaySubnetRef.?vnetRef ?? '', instance.?gatewaySubnetRef.?subnetRef ?? '')
}]

resource circuits 'Microsoft.Network/expressRouteCircuits@2025-07-01' = [for circuit in resolvedInstances: if (circuit.deployCircuit) {
  name: circuit.name
  location: location
  tags: tags
  sku: {
    name: '${circuit.tier}_${circuit.family}'
    tier: circuit.tier
    family: circuit.family
  }
  properties: {
    allowClassicOperations: false
    serviceProviderProperties: {
      serviceProviderName: circuit.provider
      peeringLocation: circuit.peeringLocation
      bandwidthInMbps: circuit.bandwidth
    }
  }
}]

resource publicIps 'Microsoft.Network/publicIPAddresses@2025-07-01' = [for gateway in resolvedInstances: if (!empty(gateway.subnetId)) {
  name: take('pip-${gateway.gatewayName}', 80)
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}]

resource gateways 'Microsoft.Network/virtualNetworkGateways@2025-07-01' = [for (gateway, index) in resolvedInstances: if (!empty(gateway.subnetId)) {
  name: gateway.gatewayName
  location: location
  tags: tags
  properties: {
    gatewayType: 'ExpressRoute'
    sku: {
      name: gateway.gatewaySku
      tier: gateway.gatewaySku
    }
    ipConfigurations: [
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gateway.subnetId
          }
          publicIPAddress: {
            id: publicIps[index].id
          }
        }
      }
    ]
  }
}]

output configurations serviceConfigType[] = instances
