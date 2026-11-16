// Microsoft Sentinel on a Log Analytics workspace tile, with its SOC role assignments.
targetScope = 'resourceGroup'

type serviceConfigType = {
  resourceName: string
  @description('Values resolved by Skyforge.')
  deploy: object
}

@description('Microsoft Sentinel instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
#disable-next-line no-unused-params
param location string

@description('Tags shared by this infrastructure package.')
#disable-next-line no-unused-params
param tags object = {}

// Sentinel is turned on in the workspace's own resource group.
module workspaces 'sentinel-workspace.bicep' = [for instance in instances: {
  name: take('sentinel-${instance.deploy.workspace.name}', 64)
  scope: resourceGroup(instance.deploy.workspace.?subscriptionId ?? subscription().subscriptionId, instance.deploy.workspace.resourceGroup)
  params: {
    workspaceName: instance.deploy.workspace.name
    roleAssignments: instance.deploy.roleAssignments
  }
}]

output configurations serviceConfigType[] = instances
