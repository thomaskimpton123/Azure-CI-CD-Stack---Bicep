// Continuously exports Defender for Cloud data for the subscription to a Log Analytics workspace.
targetScope = 'resourceGroup'

@description('Name of the export automation.')
param name string

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

@description('Log Analytics workspace (a Log Analytics Workspace tile).')
param workspaceName string

@description('Defender data types exported (Assessments, Alerts, SecureScores).')
param sources string[]

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: workspaceName
}

resource export 'Microsoft.Security/automations@2023-12-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    isEnabled: true
    description: 'Continuous export of Defender for Cloud data to Log Analytics.'
    scopes: [
      {
        description: 'Subscription'
        scopePath: subscription().id
      }
    ]
    sources: map(sources, source => {
      eventSource: source
    })
    actions: [
      {
        actionType: 'Workspace'
        workspaceResourceId: workspace.id
      }
    ]
  }
}
