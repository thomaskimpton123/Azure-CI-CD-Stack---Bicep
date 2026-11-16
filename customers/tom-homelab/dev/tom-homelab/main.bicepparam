using './main.bicep'

// ============================================================================
// PARAMETERS — edit customer and environment configuration here
// ============================================================================

param globalConfig = {
  infrastructureName: 'tom-homelab'
  customer: 'Tom - Homelab'
  workload: 'platform'
  environment: 'dev'
  location: 'australiaeast'
  costCentreOrOwner: 'Tom - Homelab'
  resourceGroupName: 'rg-enterprise-alz-hub-spoke-dev'
  tags: {}
}

// Subscriptions this package deploys to. IDs not known at intake are read from environment variables when deploying.
var subscriptions = {
  'app-dev': readEnvironmentVariable('AZ_SUBSCRIPTION_APP_DEV')
  management: readEnvironmentVariable('AZ_SUBSCRIPTION_MANAGEMENT')
  connectivity: readEnvironmentVariable('AZ_SUBSCRIPTION_CONNECTIVITY')
  identity: readEnvironmentVariable('AZ_SUBSCRIPTION_IDENTITY')
}

param subscriptionIds = subscriptions

// Selected Azure services. Each service is a list — add or remove instances in Skyforge.
param serviceConfigurations = {
  automation: [
    {
      resourceName: 'auto-platform-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: [
          {
            name: 'log-platform-aue-01'
            resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
            subscriptionId: subscriptions.management
          }
        ]
        publicNetworkAccess: 'Disabled'
        runbooks: [
          {
            name: 'policy-remediation'
            type: 'PowerShell'
            runtime: 'PowerShell-7.4'
          }
          {
            name: 'subscription-vending-audit'
            type: 'PowerShell'
            runtime: 'PowerShell-7.4'
          }
        ]
        powerShell74: true
        workerGroups: []
      }
      subscriptionId: subscriptions.management
    }
  ]
  azureFirewall: [
    {
      resourceName: 'afw-hub-aue-01'
      skuName: 'AZFW_VNet'
      skuTier: 'Premium'
      zones: '1,2,3'
      firewallSubnetId: {
        vnetRef: 'vnet-hub-aue-01'
        vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
        subnetRef: 'AzureFirewallSubnet'
        vnetSubscriptionId: subscriptions.connectivity
      }
      publicIpCount: '1'
      threatIntelMode: 'AlertAndDeny'
      dnsProxy: true
      idpsMode: 'Alert'
      tlsInspectionEnabled: false
      urlFilteringEnabled: true
      blockedWebCategories: []
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      diagnosticWorkspaceRef: 'log-security-aue-01'
      rules: []
      subscriptionId: subscriptions.connectivity
    }
  ]
  azurePolicy: [
    {
      resourceName: 'policy-alz-guardrails'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        assignments: [
          {
            name: 'security-baseline'
            definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8'
            enforcementMode: 'Default'
            message: 'Microsoft cloud security baseline'
            parameters: {}
            notScopes: []
            identity: {}
          }
        ]
        exemptions: []
        remediationRoles: []
      }
      scopeType: 'ManagementGroup'
      managementGroup: 'mg-platform'
    }
    {
      resourceName: 'policy-alz-guardrails'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        assignments: [
          {
            name: 'allowed-regions'
            definitionId: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
            enforcementMode: 'Default'
            message: 'Australia East and Australia Southeast'
            parameters: {
              listOfAllowedLocations: {
                value: [
                  'australiaeast'
                  'australiasoutheast'
                ]
              }
            }
            notScopes: []
            identity: {}
          }
          {
            name: 'required-tags'
            definitionId: '/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99'
            enforcementMode: 'Default'
            message: 'Every resource has an Owner tag'
            parameters: {
              tagName: {
                value: 'Owner'
              }
            }
            notScopes: []
            identity: {}
          }
        ]
        exemptions: []
        remediationRoles: []
      }
      scopeType: 'ManagementGroup'
      managementGroup: 'mg-landing-zones'
    }
  ]
  backup: [
    {
      resourceName: 'rsv-platform-aue-01'
      vaultType: 'RecoveryServicesVault'
      redundancyAndCrossRegionRestore: 'GRS+CRR'
      protectedWorkloads: []
      policies: []
      softDeleteEnabled: true
      softDeleteRetentionDays: '14'
      immutabilityState: 'Unlocked'
      muaEnabled: true
      identityAssignments: []
      cmkEnabled: false
      vaultRoleAssignments: []
      diagnosticWorkspaceRef: 'log-platform-aue-01'
      restoreTestFrequency: 'Quarterly'
      privateConnectivity: false
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      subscriptionId: subscriptions.management
    }
  ]
  bastion: [
    {
      resourceName: 'bas-hub-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: [
          {
            name: 'log-platform-aue-01'
            resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
            subscriptionId: subscriptions.management
          }
        ]
        sku: 'Standard'
        vnet: {
          name: 'vnet-hub-aue-01'
          resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
          subscriptionId: subscriptions.connectivity
        }
        zones: [
          1
          2
          3
        ]
        scaleUnits: 2
        ipConnect: true
        kerberos: false
        shareableLink: false
        sessionRecording: false
      }
      subscriptionId: subscriptions.connectivity
    }
  ]
  costManagement: [
    {
      resourceName: 'cost-alz-finops'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        budgets: [
          {
            name: 'budget-monthly'
            amount: 5000
            timeGrain: 'Monthly'
            notifications: {
              actual_80: {
                enabled: true
                operator: 'GreaterThanOrEqualTo'
                threshold: 80
                thresholdType: 'Actual'
                contactEmails: [
                  'finops@example.com'
                ]
              }
              actual_100: {
                enabled: true
                operator: 'GreaterThanOrEqualTo'
                threshold: 100
                thresholdType: 'Actual'
                contactEmails: [
                  'finops@example.com'
                ]
              }
            }
          }
          {
            name: 'budget-monthly-forecast'
            amount: 5000
            timeGrain: 'Monthly'
            notifications: {
              forecasted_100: {
                enabled: true
                operator: 'GreaterThanOrEqualTo'
                threshold: 100
                thresholdType: 'Forecasted'
                contactEmails: [
                  'finops@example.com'
                ]
              }
            }
          }
        ]
      }
      subscriptionId: subscriptions.management
    }
  ]
  ddos: [
    {
      resourceName: 'ddos-hub-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
      }
      subscriptionId: subscriptions.connectivity
    }
  ]
  defenderCloud: [
    {
      resourceName: 'defender-platform-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: [
          {
            name: 'log-security-aue-01'
            resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
            subscriptionId: subscriptions.management
          }
        ]
        plans: [
          {
            name: 'CloudPosture'
            tier: 'Standard'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'VirtualMachines'
            tier: 'Standard'
            subPlan: 'P2'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'StorageAccounts'
            tier: 'Standard'
            subPlan: 'DefenderForStorageV2'
          }
          {
            name: 'KeyVaults'
            tier: 'Standard'
            subPlan: 'PerKeyVault'
          }
        ]
        minimalSeverity: 'High'
        standards: [
          {
            definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/5e4ff661-23bf-42fa-8e3a-309a55091cc7'
            displayName: 'ISO/IEC 27001 2022'
          }
        ]
        export: {}
      }
      subscriptionId: subscriptions['app-dev']
    }
    {
      resourceName: 'defender-platform-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: [
          {
            name: 'log-security-aue-01'
            resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
            subscriptionId: subscriptions.management
          }
        ]
        plans: [
          {
            name: 'CloudPosture'
            tier: 'Standard'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'VirtualMachines'
            tier: 'Standard'
            subPlan: 'P2'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'StorageAccounts'
            tier: 'Standard'
            subPlan: 'DefenderForStorageV2'
          }
          {
            name: 'KeyVaults'
            tier: 'Standard'
            subPlan: 'PerKeyVault'
          }
        ]
        minimalSeverity: 'High'
        standards: [
          {
            definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/5e4ff661-23bf-42fa-8e3a-309a55091cc7'
            displayName: 'ISO/IEC 27001 2022'
          }
        ]
        export: {}
      }
      subscriptionId: subscriptions.management
    }
    {
      resourceName: 'defender-platform-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: [
          {
            name: 'log-security-aue-01'
            resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
            subscriptionId: subscriptions.management
          }
        ]
        plans: [
          {
            name: 'CloudPosture'
            tier: 'Standard'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'VirtualMachines'
            tier: 'Standard'
            subPlan: 'P2'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'StorageAccounts'
            tier: 'Standard'
            subPlan: 'DefenderForStorageV2'
          }
          {
            name: 'KeyVaults'
            tier: 'Standard'
            subPlan: 'PerKeyVault'
          }
        ]
        minimalSeverity: 'High'
        standards: [
          {
            definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/5e4ff661-23bf-42fa-8e3a-309a55091cc7'
            displayName: 'ISO/IEC 27001 2022'
          }
        ]
        export: {}
      }
      subscriptionId: subscriptions.connectivity
    }
    {
      resourceName: 'defender-platform-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: [
          {
            name: 'log-security-aue-01'
            resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
            subscriptionId: subscriptions.management
          }
        ]
        plans: [
          {
            name: 'CloudPosture'
            tier: 'Standard'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'VirtualMachines'
            tier: 'Standard'
            subPlan: 'P2'
            extensions: [
              {
                name: 'AgentlessVmScanning'
                isEnabled: 'True'
              }
            ]
          }
          {
            name: 'StorageAccounts'
            tier: 'Standard'
            subPlan: 'DefenderForStorageV2'
          }
          {
            name: 'KeyVaults'
            tier: 'Standard'
            subPlan: 'PerKeyVault'
          }
        ]
        minimalSeverity: 'High'
        standards: [
          {
            definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/5e4ff661-23bf-42fa-8e3a-309a55091cc7'
            displayName: 'ISO/IEC 27001 2022'
          }
        ]
        export: {}
      }
      subscriptionId: subscriptions.identity
    }
  ]
  dnsPrivateResolver: [
    {
      resourceName: 'dnspr-hub-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        vnet: {
          name: 'vnet-hub-aue-01'
          resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
          subscriptionId: subscriptions.connectivity
        }
        inboundSubnet: {
          vnetRef: 'vnet-hub-aue-01'
          vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
          subnetRef: 'dns-inbound'
          vnetSubscriptionId: subscriptions.connectivity
        }
        outboundSubnet: {
          vnetRef: 'vnet-hub-aue-01'
          vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
          subnetRef: 'dns-outbound'
          vnetSubscriptionId: subscriptions.connectivity
        }
        forwardingRules: []
        rulesetVnetLinks: []
      }
      subscriptionId: subscriptions.connectivity
    }
  ]
  expressroute: [
    {
      resourceName: 'er-primary-aue-01'
      bandwidthMbps: '1000'
      skuTier: 'Premium'
      billingModel: 'MeteredData'
      deployCircuit: false
      gatewaySku: 'ErGw2AZ'
      gatewaySubnetRef: {
        vnetRef: 'vnet-hub-aue-01'
        vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
        subnetRef: 'GatewaySubnet'
        vnetSubscriptionId: subscriptions.connectivity
      }
      fastPath: true
      secondaryCircuit: true
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      subscriptionId: subscriptions.connectivity
    }
  ]
  logAnalytics: [
    {
      resourceName: 'log-platform-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        skuName: 'PerGB2018'
        skuCapacityReservationLevel: 100
        dataRetention: 90
        dailyQuotaGb: '-1'
        resourceContextAccess: true
        publicIngestion: true
        publicQuery: true
      }
      subscriptionId: subscriptions.management
    }
    {
      resourceName: 'log-security-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        skuName: 'PerGB2018'
        skuCapacityReservationLevel: 100
        dataRetention: 90
        dailyQuotaGb: '-1'
        resourceContextAccess: true
        publicIngestion: true
        publicQuery: true
      }
      subscriptionId: subscriptions.management
    }
  ]
  managedIdentities: [
    {
      resourceName: 'id-platform-ops-aue-01'
      roleAssignments: []
      customRoles: []
      federatedCredentials: []
      crossSubscriptionRequired: false
      crossSubscriptionTargets: []
      accessReviewFrequency: 'Quarterly'
      orphanCleanupProcess: 'Automated'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-identity'
      subscriptionId: subscriptions.identity
    }
  ]
  networkWatcher: [
    {
      resourceName: 'nw-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        flowLogs: []
      }
      subscriptionId: subscriptions['app-dev']
    }
  ]
  privateDns: [
    {
      resourceName: 'pdns-alz-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        zones: [
          {
            resourceName: 'privatelink.azurewebsites.net'
            deploy: {
              a: []
              aaaa: []
              cname: []
              txt: []
              ptr: []
              srv: []
              links: [
                {
                  name: 'vnet-corp-aue-01'
                  resourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
                  registrationEnabled: false
                  subscriptionId: subscriptions['app-dev']
                }
              ]
            }
          }
          {
            resourceName: 'privatelink.vaultcore.azure.net'
            deploy: {
              a: []
              aaaa: []
              cname: []
              txt: []
              ptr: []
              srv: []
              links: [
                {
                  name: 'vnet-corp-aue-01'
                  resourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
                  registrationEnabled: false
                  subscriptionId: subscriptions['app-dev']
                }
              ]
            }
          }
          {
            resourceName: 'privatelink.blob.core.windows.net'
            deploy: {
              a: []
              aaaa: []
              cname: []
              txt: []
              ptr: []
              srv: []
              links: [
                {
                  name: 'vnet-corp-aue-01'
                  resourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
                  registrationEnabled: false
                  subscriptionId: subscriptions['app-dev']
                }
              ]
            }
          }
        ]
      }
      subscriptionId: subscriptions.connectivity
    }
  ]
  resourceGroups: [
    {
      resourceName: 'rg-enterprise-alz-hub-spoke-dev'
      subscriptionRef: 'app-dev'
      purpose: 'Application workload'
      lockLevel: 'CanNotDelete'
      lockNotes: 'Managed by the Azure infrastructure pack'
      tags: {}
      subscriptionId: subscriptions['app-dev']
    }
    {
      resourceName: 'rg-enterprise-alz-hub-spoke-dev-management'
      subscriptionRef: 'management'
      purpose: 'Application workload'
      lockLevel: 'CanNotDelete'
      lockNotes: 'Managed by the Azure infrastructure pack'
      tags: {}
      subscriptionId: subscriptions.management
    }
    {
      resourceName: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      subscriptionRef: 'connectivity'
      purpose: 'Application workload'
      lockLevel: 'CanNotDelete'
      lockNotes: 'Managed by the Azure infrastructure pack'
      tags: {}
      subscriptionId: subscriptions.connectivity
    }
    {
      resourceName: 'rg-enterprise-alz-hub-spoke-dev-identity'
      subscriptionRef: 'identity'
      purpose: 'Application workload'
      lockLevel: 'CanNotDelete'
      lockNotes: 'Managed by the Azure infrastructure pack'
      tags: {}
      subscriptionId: subscriptions.identity
    }
  ]
  routeTables: [
    {
      resourceName: 'rt-corp-egress-aue-01'
      disableBgpRoutePropagation: false
      subnetAssociations: [
        {
          vnetRef: 'vnet-corp-aue-01'
          vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
          subnetRef: 'workload'
          vnetSubscriptionId: subscriptions['app-dev']
        }
        {
          vnetRef: 'vnet-online-aue-01'
          vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
          subnetRef: 'web'
          vnetSubscriptionId: subscriptions['app-dev']
        }
      ]
      routes: [
        {
          name: 'default-via-firewall'
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.100.0.4'
        }
      ]
      validateSymmetricRouting: true
      routeOwner: 'Platform network team'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev'
      subscriptionId: subscriptions['app-dev']
    }
  ]
  sentinel: [
    {
      resourceName: 'sentinel-security-aue-01'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-management'
      deploy: {
        systemAssigned: false
        userAssignedIdentities: []
        roleAssignments: []
        diagnosticWorkspaces: []
        workspace: {
          name: 'log-security-aue-01'
          resourceGroup: 'rg-enterprise-alz-hub-spoke-dev-management'
          subscriptionId: subscriptions.management
        }
      }
      subscriptionId: subscriptions.management
    }
  ]
  vnet: [
    {
      resourceName: 'vnet-hub-aue-01'
      addressSpaces: [
        '10.100.0.0/16'
      ]
      subnets: [
        {
          name: 'AzureFirewallSubnet'
          cidr: '10.100.0.0/26'
        }
        {
          name: 'AzureBastionSubnet'
          cidr: '10.100.0.64/26'
        }
        {
          name: 'GatewaySubnet'
          cidr: '10.100.0.128/27'
        }
        {
          name: 'dns-inbound'
          cidr: '10.100.1.0/28'
        }
        {
          name: 'dns-outbound'
          cidr: '10.100.1.16/28'
        }
      ]
      vnetEncryption: false
      deployBastion: false
      ddosNetworkProtection: true
      subnetDelegations: [
        {
          subnet: 'dns-inbound'
          service: 'Microsoft.Network/dnsResolvers'
        }
        {
          subnet: 'dns-outbound'
          service: 'Microsoft.Network/dnsResolvers'
        }
      ]
      dnsServers: []
      peerings: [
        {
          remoteVnetName: 'vnet-corp-aue-01'
          remoteResourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
          allowForwardedTraffic: true
          allowGatewayTransit: true
          useRemoteGateways: false
          remoteSubscriptionId: subscriptions['app-dev']
        }
        {
          remoteVnetName: 'vnet-online-aue-01'
          remoteResourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
          allowForwardedTraffic: true
          allowGatewayTransit: true
          useRemoteGateways: false
          remoteSubscriptionId: subscriptions['app-dev']
        }
      ]
      serviceEndpoints: []
      defaultOutboundAccess: false
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      subnetNsgs: []
      subnetRouteTables: []
      subnetNatGateways: []
      ddosPlanName: 'ddos-hub-aue-01'
      ddosPlanResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      ddosPlanSubscriptionId: subscriptions.connectivity
      subscriptionId: subscriptions.connectivity
    }
    {
      resourceName: 'vnet-corp-aue-01'
      addressSpaces: [
        '10.110.0.0/16'
      ]
      subnets: [
        {
          name: 'workload'
          cidr: '10.110.1.0/24'
        }
        {
          name: 'private-endpoints'
          cidr: '10.110.2.0/24'
        }
      ]
      vnetEncryption: false
      deployBastion: false
      ddosNetworkProtection: true
      subnetDelegations: []
      dnsServers: []
      peerings: [
        {
          remoteVnetName: 'vnet-hub-aue-01'
          remoteResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
          allowForwardedTraffic: true
          allowGatewayTransit: false
          useRemoteGateways: true
          remoteSubscriptionId: subscriptions.connectivity
        }
      ]
      serviceEndpoints: []
      defaultOutboundAccess: false
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev'
      subnetNsgs: []
      subnetRouteTables: [
        {
          subnet: 'workload'
          name: 'rt-corp-egress-aue-01'
          resourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
          subscriptionId: subscriptions['app-dev']
        }
      ]
      subnetNatGateways: []
      ddosPlanName: 'ddos-hub-aue-01'
      ddosPlanResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      ddosPlanSubscriptionId: subscriptions.connectivity
      subscriptionId: subscriptions['app-dev']
    }
    {
      resourceName: 'vnet-online-aue-01'
      addressSpaces: [
        '10.120.0.0/16'
      ]
      subnets: [
        {
          name: 'web'
          cidr: '10.120.1.0/24'
        }
        {
          name: 'private-endpoints'
          cidr: '10.120.2.0/24'
        }
      ]
      vnetEncryption: false
      deployBastion: false
      ddosNetworkProtection: true
      subnetDelegations: []
      dnsServers: []
      peerings: [
        {
          remoteVnetName: 'vnet-hub-aue-01'
          remoteResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
          allowForwardedTraffic: true
          allowGatewayTransit: false
          useRemoteGateways: true
          remoteSubscriptionId: subscriptions.connectivity
        }
      ]
      serviceEndpoints: []
      defaultOutboundAccess: false
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev'
      subnetNsgs: []
      subnetRouteTables: [
        {
          subnet: 'web'
          name: 'rt-corp-egress-aue-01'
          resourceGroup: 'rg-enterprise-alz-hub-spoke-dev'
          subscriptionId: subscriptions['app-dev']
        }
      ]
      subnetNatGateways: []
      ddosPlanName: 'ddos-hub-aue-01'
      ddosPlanResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      ddosPlanSubscriptionId: subscriptions.connectivity
      subscriptionId: subscriptions['app-dev']
    }
  ]
  vpnGateway: [
    {
      resourceName: 'vpngw-hub-aue-01'
      gatewayType: 'Vpn'
      vpnType: 'RouteBased'
      skuName: 'VpnGw2AZ'
      activeActive: true
      gatewaySubnetRef: {
        vnetRef: 'vnet-hub-aue-01'
        vnetResourceGroup: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
        subnetRef: 'GatewaySubnet'
        vnetSubscriptionId: subscriptions.connectivity
      }
      bgpEnabled: true
      bgpAsn: '65515'
      p2sEnabled: false
      p2sAddressPool: '172.16.0.0/24'
      p2sProtocols: 'OpenVPN,IkeV2'
      p2sAuthentication: 'Entra ID'
      resourceGroupRef: 'rg-enterprise-alz-hub-spoke-dev-connectivity'
      sites: []
      p2sProtocolList: [
        'OpenVPN'
        'IkeV2'
      ]
      subscriptionId: subscriptions.connectivity
    }
  ]
}

