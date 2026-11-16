// Turns on Microsoft Sentinel for a workspace and grants its SOC roles.
targetScope = 'resourceGroup'

@description('Log Analytics workspace (a Log Analytics Workspace tile).')
param workspaceName string

@description('SOC role assignments on the workspace.')
param roleAssignments array = []

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: workspaceName
}

resource onboarding 'Microsoft.SecurityInsights/onboardingStates@2024-09-01' = {
  scope: workspace
  name: 'default'
  properties: {}
}

resource socRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roleAssignments: {
  name: guid(workspace.id, role.principalId, role.roleId)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.roleId)
    principalId: role.principalId
  }
}]
