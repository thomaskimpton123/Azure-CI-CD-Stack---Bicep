// Azure Policy assignments, exclusions and exemptions for the subscription this package deploys to.
targetScope = 'subscription'

type serviceConfigType = {
  resourceName: string
  @description('Values resolved by Skyforge.')
  deploy: object
}

@description('Azure Policy instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
#disable-next-line no-unused-params
param tags object = {}

var assignments = flatten(map(instances, instance => instance.deploy.assignments))

// The assignment identity (used for remediation) lives in the package region.
resource policyAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [for assignment in assignments: {
  name: assignment.name
  location: location
  identity: empty(assignment.?identity.?name ?? '') ? {
    type: 'SystemAssigned'
  } : {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(assignment.identity.?subscriptionId ?? subscription().subscriptionId, assignment.identity.resourceGroup, 'Microsoft.ManagedIdentity/userAssignedIdentities', assignment.identity.name)}': {}
    }
  }
  properties: {
    displayName: assignment.name
    policyDefinitionId: assignment.definitionId
    definitionVersion: assignment.?version
    enforcementMode: assignment.enforcementMode
    parameters: assignment.?parameters ?? {}
    notScopes: map(assignment.notScopes, path => startsWith(path, '/subscriptions/') ? path : '${subscription().id}${path}')
    nonComplianceMessages: empty(assignment.?message ?? '') ? [] : [
      {
        message: assignment.message
      }
    ]
  }
}]

resource exemptions 'Microsoft.Authorization/policyExemptions@2022-07-01-preview' = [for exemption in flatten(map(instances, instance => instance.deploy.exemptions)): {
  name: exemption.name
  properties: {
    displayName: exemption.name
    description: exemption.?description
    policyAssignmentId: subscriptionResourceId('Microsoft.Authorization/policyAssignments', exemption.assignment)
    exemptionCategory: exemption.category
    expiresOn: empty(exemption.?expiresOn ?? '') ? null : '${exemption.expiresOn}T00:00:00Z'
  }
  dependsOn: [policyAssignments]
}]

// Principals that remediate non-compliant resources across the subscription.
resource remediationRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in flatten(map(instances, instance => instance.deploy.remediationRoles)): {
  name: guid(subscription().id, role.principalId, role.roleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.roleId)
    principalId: role.principalId
  }
}]

output configurations serviceConfigType[] = instances
