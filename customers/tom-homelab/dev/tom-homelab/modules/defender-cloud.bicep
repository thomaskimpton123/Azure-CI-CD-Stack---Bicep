// Microsoft Defender for Cloud for the subscription: plans, security contacts, regulatory
// standards and continuous export to Log Analytics.
targetScope = 'subscription'

type serviceConfigType = {
  resourceName: string
  @description('Values resolved by Skyforge.')
  deploy: object
}

@description('Defender for Cloud instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

// Plans are updated one at a time; Defender rejects concurrent pricing changes.
@batchSize(1)
resource pricings 'Microsoft.Security/pricings@2024-01-01' = [for plan in flatten(map(instances, instance => instance.deploy.plans)): {
  name: plan.name
  properties: {
    pricingTier: plan.tier
    subPlan: plan.?subPlan
    extensions: plan.?extensions
  }
}]

// The subscription has one security contact setting (a package has one Defender for Cloud tile).
var contactEmails = first(instances).?deploy.?contactEmails ?? ''
var minimalSeverity = first(instances).?deploy.?minimalSeverity ?? 'High'

resource securityContacts 'Microsoft.Security/securityContacts@2023-12-01-preview' = if (!empty(contactEmails)) {
  name: 'default'
  properties: {
    emails: contactEmails
    isEnabled: true
    notificationsByRole: {
      state: 'On'
      roles: [
        'Owner'
      ]
    }
    notificationsSources: [
      {
        sourceType: 'Alert'
        minimalSeverity: minimalSeverity
      }
    ]
  }
}

// Each regulatory standard is its Azure Policy initiative, assigned to the subscription.
resource standards 'Microsoft.Authorization/policyAssignments@2024-04-01' = [for standard in flatten(map(instances, instance => instance.deploy.standards)): {
  name: guid(subscription().id, standard.definitionId)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: standard.displayName
    description: 'Regulatory compliance standard tracked in Microsoft Defender for Cloud.'
    policyDefinitionId: standard.definitionId
  }
}]

module continuousExport 'defender-export.bicep' = [for instance in filter(instances, instance => !empty(instance.deploy.?export ?? {})): {
  name: take('defender-export-${instance.resourceName}', 64)
  scope: resourceGroup(instance.deploy.export.?subscriptionId ?? subscription().subscriptionId, instance.deploy.export.resourceGroup)
  params: {
    name: 'ExportToWorkspace'
    location: location
    tags: tags
    workspaceName: instance.deploy.export.workspace
    sources: instance.deploy.export.sources
  }
}]

output configurations serviceConfigType[] = instances
