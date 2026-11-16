// Azure Firewall with a firewall policy — validated deployable composition
targetScope = 'resourceGroup'

type subnetReferenceType = {
  vnetRef: string
  vnetResourceGroup: string
  vnetSubscriptionId: string?
  subnetRef: string
}

type firewallRuleType = {
  name: string
  collectionType: ('Network' | 'Application' | 'Nat')
  priority: int
  action: string?
  protocol: string?
  sources: string[]
  destinations: string[]
  ports: string[]
  fqdnDestination: bool
  translatedAddress: string?
  translatedPort: string?
}

type serviceConfigType = {
  resourceName: string
  skuTier: ('Premium' | 'Standard' | 'Basic')?
  zones: string?
  firewallSubnetId: subnetReferenceType
  managementSubnetId: subnetReferenceType?
  publicIpCount: string?
  threatIntelMode: ('AlertAndDeny' | 'Alert' | 'Off')?
  dnsProxy: bool?
  idpsMode: ('Off' | 'Alert' | 'Deny')?
  rules: firewallRuleType[]?
}

@description('Azure Firewall instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

var threatIntelModes = {
  AlertAndDeny: 'Deny'
  Alert: 'Alert'
  Off: 'Off'
}

var resolvedInstances = [for instance in instances: {
  name: instance.resourceName
  tier: instance.?skuTier ?? 'Premium'
  zones: empty(instance.?zones ?? '1,2,3') ? [] : split(instance.?zones ?? '1,2,3', ',')
  publicIpCount: int(instance.?publicIpCount ?? '1')
  firewallSubnetId: resourceId(instance.firewallSubnetId.?vnetSubscriptionId ?? subscription().subscriptionId, instance.firewallSubnetId.vnetResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', instance.firewallSubnetId.vnetRef, instance.firewallSubnetId.subnetRef)
  // Null-safe on both branches, so the ternary is safe however the expression is evaluated.
  managementSubnetId: empty(instance.?managementSubnetId.?subnetRef ?? '') ? '' : resourceId(instance.?managementSubnetId.?vnetSubscriptionId ?? subscription().subscriptionId, instance.?managementSubnetId.?vnetResourceGroup ?? '', 'Microsoft.Network/virtualNetworks/subnets', instance.?managementSubnetId.?vnetRef ?? '', instance.?managementSubnetId.?subnetRef ?? '')
  threatIntelMode: threatIntelModes[instance.?threatIntelMode ?? 'AlertAndDeny']
  dnsProxy: instance.?dnsProxy ?? true
  idpsMode: instance.?idpsMode ?? 'Alert'
  rules: instance.?rules ?? []
}]

var publicIpSpecs = concat(
  flatten(map(resolvedInstances, firewall => map(range(1, firewall.publicIpCount), number => {
    name: take('pip-${firewall.name}-${number}', 80)
    zones: firewall.zones
  }))),
  map(filter(resolvedInstances, firewall => !empty(firewall.managementSubnetId)), firewall => {
    name: take('pip-${firewall.name}-mgmt', 80)
    zones: firewall.zones
  })
)

resource publicIps 'Microsoft.Network/publicIPAddresses@2025-07-01' = [for spec in publicIpSpecs: {
  name: spec.name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: spec.zones
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}]

resource policies 'Microsoft.Network/firewallPolicies@2025-07-01' = [for firewall in resolvedInstances: {
  name: take('afwp-${firewall.name}', 80)
  location: location
  tags: tags
  properties: {
    sku: {
      tier: firewall.tier
    }
    threatIntelMode: firewall.threatIntelMode
    dnsSettings: firewall.tier == 'Basic' ? null : {
      enableProxy: firewall.dnsProxy
    }
    intrusionDetection: firewall.tier == 'Premium' ? {
      mode: firewall.idpsMode
    } : null
  }
}]

// One collection per Skyforge rule row, all in a single rule collection group.
resource ruleGroups 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-07-01' = [for (firewall, index) in resolvedInstances: if (!empty(firewall.rules)) {
  parent: policies[index]
  name: 'intake-rules'
  properties: {
    priority: 200
    ruleCollections: map(firewall.rules, rule => rule.collectionType == 'Nat' ? {
      ruleCollectionType: 'FirewallPolicyNatRuleCollection'
      name: rule.name
      priority: rule.priority
      action: {
        type: 'DNAT'
      }
      rules: [
        {
          ruleType: 'NatRule'
          name: rule.name
          ipProtocols: [rule.?protocol ?? 'TCP']
          sourceAddresses: rule.sources
          // DNAT always arrives on the firewall's first public IP.
          destinationAddresses: [reference(resourceId('Microsoft.Network/publicIPAddresses', take('pip-${firewall.name}-1', 80)), '2025-07-01').ipAddress]
          destinationPorts: rule.ports
          translatedAddress: rule.?translatedAddress ?? ''
          translatedPort: rule.?translatedPort ?? ''
        }
      ]
    } : {
      ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
      name: rule.name
      priority: rule.priority
      action: {
        type: rule.?action ?? 'Allow'
      }
      rules: [
        rule.collectionType == 'Application' ? {
          ruleType: 'ApplicationRule'
          name: rule.name
          sourceAddresses: rule.sources
          targetFqdns: rule.destinations
          protocols: map(rule.ports, port => {
            protocolType: rule.?protocol == 'HTTP' ? 'Http' : 'Https'
            port: int(port)
          })
        } : {
          ruleType: 'NetworkRule'
          name: rule.name
          ipProtocols: [rule.?protocol ?? 'TCP']
          sourceAddresses: rule.sources
          destinationAddresses: rule.fqdnDestination ? [] : rule.destinations
          destinationFqdns: rule.fqdnDestination ? rule.destinations : []
          destinationPorts: rule.ports
        }
      ]
    })
  }
  dependsOn: [publicIps]
}]

resource firewalls 'Microsoft.Network/azureFirewalls@2025-07-01' = [for (firewall, index) in resolvedInstances: {
  name: firewall.name
  location: location
  tags: tags
  zones: firewall.zones
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewall.tier
    }
    firewallPolicy: {
      id: policies[index].id
    }
    // Azure gives the firewall the first usable address of AzureFirewallSubnet (.4); route tables in
    // this package point at that address.
    ipConfigurations: map(range(1, firewall.publicIpCount), number => {
      name: 'ipconfig-${number}'
      properties: union({
        publicIPAddress: {
          id: resourceId('Microsoft.Network/publicIPAddresses', take('pip-${firewall.name}-${number}', 80))
        }
      }, number == 1 ? {
        subnet: {
          id: firewall.firewallSubnetId
        }
      } : {})
    })
    managementIpConfiguration: empty(firewall.managementSubnetId) ? null : {
      name: 'mgmt-ipconfig'
      properties: {
        subnet: {
          id: firewall.managementSubnetId
        }
        publicIPAddress: {
          id: resourceId('Microsoft.Network/publicIPAddresses', take('pip-${firewall.name}-mgmt', 80))
        }
      }
    }
  }
  dependsOn: [publicIps, ruleGroups]
}]

output configurations serviceConfigType[] = instances
