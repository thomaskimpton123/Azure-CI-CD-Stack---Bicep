// Azure Policy assignments, exclusions and exemptions on a management group, so they cover every
// subscription below it.
targetScope = 'managementGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values resolved by Skyforge.')
  deploy: object
}

@description('Azure Policy instances for this management group.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package (the assignment identity lives here).')
param location string

var assignments = flatten(map(instances, instance => instance.deploy.assignments))

resource policyAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [for assignment in assignments: {
  name: assignment.name
  location: location
  identity: empty(assignment.?identity.?name ?? '') ? {
    type: 'SystemAssigned'
  } : {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(assignment.identity.subscriptionId, assignment.identity.resourceGroup, 'Microsoft.ManagedIdentity/userAssignedIdentities', assignment.identity.name)}': {}
    }
  }
  properties: {
    displayName: assignment.name
    policyDefinitionId: assignment.definitionId
    definitionVersion: assignment.?version
    enforcementMode: assignment.enforcementMode
    parameters: assignment.?parameters ?? {}
    // Exclusions are full resource IDs here; a management group has no subscription of its own.
    notScopes: filter(assignment.notScopes, path => startsWith(path, '/subscriptions/'))
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
    policyAssignmentId: managementGroupResourceId('Microsoft.Authorization/policyAssignments', exemption.assignment)
    exemptionCategory: exemption.category
    expiresOn: empty(exemption.?expiresOn ?? '') ? null : '${exemption.expiresOn}T00:00:00Z'
  }
  dependsOn: [policyAssignments]
}]

// Principals that remediate non-compliant resources below the management group.
resource remediationRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in flatten(map(instances, instance => instance.deploy.remediationRoles)): {
  name: guid(managementGroup().id, role.principalId, role.roleId)
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', role.roleId)
    principalId: role.principalId
  }
}]

output configurations serviceConfigType[] = instances
