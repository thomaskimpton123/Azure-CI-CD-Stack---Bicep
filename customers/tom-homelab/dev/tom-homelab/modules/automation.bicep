// Automation account — deployable through Azure Verified Module avm/res/automation/automation-account 0.19.3
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values passed to the AVM module, resolved by Skyforge.')
  deploy: object
}

@description('Automation account instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

module resources 'br/public:avm/res/automation/automation-account:0.19.3' = [for (instance, index) in instances: {
  name: take('avm-aa-${instance.resourceName}', 64)
  params: {
    name: instance.resourceName
    location: location
    tags: tags
    enableTelemetry: false
    skuName: 'Basic'
    publicNetworkAccess: instance.deploy.publicNetworkAccess
    disableLocalAuth: true
    hybridRunbookWorkerGroups: map(instance.deploy.workerGroups, group => {
      name: group
    })
    managedIdentities: {
      systemAssigned: instance.deploy.systemAssigned
      userAssignedResourceIds: map(instance.deploy.userAssignedIdentities, identity => resourceId(identity.?subscriptionId ?? subscription().subscriptionId, identity.resourceGroup, 'Microsoft.ManagedIdentity/userAssignedIdentities', identity.name))
    }
    roleAssignments: map(filter(instance.deploy.roleAssignments, assignment => !empty(assignment.principalId)), assignment => {
      roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleId)
      principalId: assignment.principalId
    })
    diagnosticSettings: map(instance.deploy.diagnosticWorkspaces, workspace => {
      workspaceResourceId: resourceId(workspace.?subscriptionId ?? subscription().subscriptionId, workspace.resourceGroup, 'Microsoft.OperationalInsights/workspaces', workspace.name)
    })
  }
}]

// PowerShell 7.4 runs in a runtime environment the account creates; Python 3.10 and PowerShell 5.1 are built in.
resource runtimeEnvironments 'Microsoft.Automation/automationAccounts/runtimeEnvironments@2024-10-23' = [for instance in filter(instances, instance => instance.deploy.powerShell74): {
  name: '${instance.resourceName}/PowerShell-7.4'
  location: location
  tags: tags
  properties: {
    runtime: {
      language: 'PowerShell'
      version: '7.4'
    }
    defaultPackages: {
      Az: '12.3.0'
    }
  }
  dependsOn: [resources]
}]

// Runbooks start as empty drafts; their code is published from source control or the portal.
var runbooks = flatten(map(instances, instance => map(instance.deploy.runbooks, runbook => union(runbook, {
  account: instance.resourceName
}))))

resource runbookDrafts 'Microsoft.Automation/automationAccounts/runbooks@2024-10-23' = [for runbook in runbooks: {
  name: '${runbook.account}/${runbook.name}'
  location: location
  tags: tags
  properties: {
    runbookType: runbook.type
    runtimeEnvironment: runbook.runtime
    logProgress: false
    logVerbose: false
  }
  dependsOn: [resources, runtimeEnvironments]
}]

var identityRoleAssignments = flatten(map(instances, instance => map(filter(instance.deploy.roleAssignments, assignment => empty(assignment.principalId)), assignment => {
  targetName: instance.resourceName
  roleId: assignment.roleId
  dataPlane: assignment.dataPlane
  identityName: assignment.identityName
  identityResourceGroup: assignment.identityResourceGroup
  identitySubscriptionId: assignment.?identitySubscriptionId ?? subscription().subscriptionId
})))

module identityRoles 'automation-identity-roles.bicep' = [for (assignment, index) in identityRoleAssignments: {
  name: take('roles-aa-${index}-${assignment.targetName}', 64)
  params: {
    targetName: assignment.targetName
    roleId: assignment.roleId
    identityName: assignment.identityName
    identityResourceGroup: assignment.identityResourceGroup
    identitySubscriptionId: assignment.?identitySubscriptionId ?? subscription().subscriptionId
  }
  dependsOn: [resources]
}]

output configurations serviceConfigType[] = instances
