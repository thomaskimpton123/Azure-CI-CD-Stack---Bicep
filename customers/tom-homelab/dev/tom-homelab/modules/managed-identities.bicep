// Managed Identities — deployable user-assigned identity composition — through Azure Verified Module avm/res/managed-identity/user-assigned-identity 0.6.0
targetScope = 'resourceGroup'

type roleAssignmentEntryType = {
  roleName: string
  scopeType: ('subscription' | 'resourceGroup')
  resourceGroupName: string?
  subscriptionId: string?
}

type customRoleEntryType = {
  roleName: string
  assignableScopes: string?
  actions: string?
  notActions: string?
  dataActions: string?
}

type federatedCredentialEntryType = {
  name: string
  issuer: string?
  subject: string?
  audience: string?
}

type crossSubscriptionTargetEntryType = {
  subscriptionOrTenantId: string
  purpose: string?
}

type serviceConfigType = {
  resourceName: string?
  resourceGroupRef: string?
  identityPurpose: string?
  roleAssignments: roleAssignmentEntryType[]?
  customRoles: customRoleEntryType[]?
  federatedCredentials: federatedCredentialEntryType[]?
  crossSubscriptionRequired: bool?
  crossSubscriptionTargets: crossSubscriptionTargetEntryType[]?
  ownerPrincipalId: string?
  accessReviewFrequency: string?
  orphanCleanupProcess: string?
}

param instances serviceConfigType[] = []
param location string
param tags object = {}

var resolvedInstances = [for (instance, index) in instances: {
  name: empty(instance.?resourceName ?? '') ? 'id-${uniqueString(resourceGroup().id, string(index))}' : (instance.?resourceName ?? '')
  purpose: instance.?identityPurpose ?? ''
  roleAssignments: map(instance.?roleAssignments ?? [], assignment => {
    roleName: assignment.roleName
    scopeType: assignment.scopeType
    resourceGroupName: assignment.scopeType == 'resourceGroup' && empty(assignment.?resourceGroupName ?? '') ? resourceGroup().name : (assignment.?resourceGroupName ?? '')
  })
}]

module userAssignedIdentities 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = [for (instance, index) in resolvedInstances: {
  name: take('avm-id-${instance.name}', 64)
  params: {
    name: instance.name
    location: location
    tags: union(tags, empty(instance.purpose) ? {} : {
      purpose: instance.purpose
    })
    enableTelemetry: false
    federatedIdentityCredentials: map(filter(instances[index].?federatedCredentials ?? [], credential => startsWith(credential.?issuer ?? '', 'https://') && !empty(credential.?subject ?? '')), credential => {
      name: credential.name
      issuer: credential.?issuer ?? ''
      subject: credential.?subject ?? ''
      audiences: [empty(credential.?audience ?? '') ? 'api://AzureADTokenExchange' : (credential.?audience ?? '')]
    })
  }
}]

// A subscription-scoped nested module keeps the per-identity role-assignment loop from nesting inside this file's own instance loop, which Bicep does not allow.
module identityRoleAssignments 'managed-identity-role-assignments.bicep' = [for (instance, index) in resolvedInstances: if (length(instance.roleAssignments) > 0) {
  scope: subscription()
  params: {
    principalId: userAssignedIdentities[index].outputs.principalId
    roleAssignments: instance.roleAssignments
  }
}]

output configurations serviceConfigType[] = instances
output identityResourceIds string[] = [for (instance, index) in resolvedInstances: userAssignedIdentities[index].outputs.resourceId]
