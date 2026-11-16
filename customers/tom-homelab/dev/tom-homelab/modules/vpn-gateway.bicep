// VPN gateways — validated deployable composition
targetScope = 'resourceGroup'

type subnetReferenceType = {
  vnetRef: string
  vnetResourceGroup: string
  vnetSubscriptionId: string?
  subnetRef: string
}

type siteType = {
  name: string
  peerAddress: string
  isFqdn: bool
  prefixes: string[]
  bgp: bool
  peerAsn: string?
  bgpPeerAddress: string?
}

type serviceConfigType = {
  resourceName: string
  skuName: string?
  activeActive: bool?
  gatewaySubnetRef: subnetReferenceType
  bgpEnabled: bool?
  bgpAsn: string?
  sites: siteType[]?
  p2sEnabled: bool?
  p2sAddressPool: string?
  p2sProtocolList: string[]?
  p2sAuthentication: string?
  p2sRootCertificateData: string?
}

@description('VPN gateway instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

@secure()
@description('Pre-shared keys by site name, supplied at deployment time. A site without a key gets its local network gateway but no connection yet.')
param sharedKeys object = {}

var resolvedInstances = [for instance in instances: {
  name: instance.resourceName
  sku: instance.?skuName ?? 'VpnGw2AZ'
  activeActive: instance.?activeActive ?? true
  subnetId: resourceId(instance.gatewaySubnetRef.?vnetSubscriptionId ?? subscription().subscriptionId, instance.gatewaySubnetRef.vnetResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', instance.gatewaySubnetRef.vnetRef, instance.gatewaySubnetRef.subnetRef)
  bgpEnabled: instance.?bgpEnabled ?? true
  bgpAsn: int(instance.?bgpAsn ?? '65515')
  sites: instance.?sites ?? []
  p2sEnabled: instance.?p2sEnabled ?? false
  p2sAddressPool: instance.?p2sAddressPool ?? ''
  p2sProtocols: instance.?p2sProtocolList ?? ['OpenVPN']
  p2sEntra: (instance.?p2sAuthentication ?? 'Entra ID') == 'Entra ID'
  p2sRootCertificateData: instance.?p2sRootCertificateData ?? ''
}]

var publicIpSpecs = flatten(map(resolvedInstances, gateway => map(range(1, gateway.activeActive ? 2 : 1), number => take('pip-${gateway.name}-${number}', 80))))

var sites = flatten(map(resolvedInstances, gateway => map(gateway.sites, site => union(site, {
  gatewayName: gateway.name
  localGatewayName: take('lgw-${gateway.name}-${site.name}', 80)
}))))

resource publicIps 'Microsoft.Network/publicIPAddresses@2025-07-01' = [for name in publicIpSpecs: {
  name: name
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

resource gateways 'Microsoft.Network/virtualNetworkGateways@2025-07-01' = [for gateway in resolvedInstances: {
  name: gateway.name
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: gateway.sku == 'VpnGw1AZ' ? 'Generation1' : 'Generation2'
    sku: {
      name: gateway.sku
      tier: gateway.sku
    }
    activeActive: gateway.activeActive
    enableBgp: gateway.bgpEnabled
    bgpSettings: gateway.bgpEnabled ? {
      asn: gateway.bgpAsn
    } : null
    ipConfigurations: map(range(1, gateway.activeActive ? 2 : 1), number => {
      name: 'ipconfig-${number}'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: {
          id: gateway.subnetId
        }
        publicIPAddress: {
          id: resourceId('Microsoft.Network/publicIPAddresses', take('pip-${gateway.name}-${number}', 80))
        }
      }
    })
    // Entra ID point-to-site uses the Microsoft-registered Azure VPN Client audience.
    vpnClientConfiguration: !gateway.p2sEnabled ? null : union({
      vpnClientAddressPool: {
        addressPrefixes: [gateway.p2sAddressPool]
      }
      vpnClientProtocols: gateway.p2sProtocols
    }, gateway.p2sEntra ? {
      vpnAuthenticationTypes: ['AAD']
      aadTenant: '${environment().authentication.loginEndpoint}${tenant().tenantId}/'
      aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
      aadIssuer: 'https://sts.windows.net/${tenant().tenantId}/'
    } : {
      vpnAuthenticationTypes: ['Certificate']
      vpnClientRootCertificates: [
        {
          name: 'p2s-root'
          properties: {
            publicCertData: gateway.p2sRootCertificateData
          }
        }
      ]
    })
  }
  dependsOn: [publicIps]
}]

resource localGateways 'Microsoft.Network/localNetworkGateways@2025-07-01' = [for site in sites: {
  name: site.localGatewayName
  location: location
  tags: tags
  properties: union(site.isFqdn ? {
    fqdn: site.peerAddress
  } : {
    gatewayIpAddress: site.peerAddress
  }, {
    localNetworkAddressSpace: {
      addressPrefixes: site.prefixes
    }
    bgpSettings: site.bgp ? {
      asn: int(site.?peerAsn ?? '0')
      bgpPeeringAddress: site.?bgpPeerAddress ?? ''
    } : null
  })
}]

resource connections 'Microsoft.Network/connections@2025-07-01' = [for (site, index) in sites: if (contains(sharedKeys, site.name)) {
  name: take('cn-${site.gatewayName}-${site.name}', 80)
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    enableBgp: site.bgp
    // Read from the @secure() sharedKeys parameter; the linter can't see that its members are secure too.
    #disable-next-line use-secure-value-for-secure-inputs
    sharedKey: sharedKeys[site.name]
    virtualNetworkGateway1: {
      id: resourceId('Microsoft.Network/virtualNetworkGateways', site.gatewayName)
      properties: {}
    }
    localNetworkGateway2: {
      id: localGateways[index].id
      properties: {}
    }
  }
  dependsOn: [gateways]
}]

output configurations serviceConfigType[] = instances
