// Resource Groups — validated subscription-scope composition
targetScope = 'subscription'

type resourceGroupConfigType = {
  resourceName: string
  subscriptionRef: string?
  location: string?
  purpose: string?
  managedBy: string?
  lockLevel: ('CanNotDelete' | 'ReadOnly' | 'None')?
  lockNotes: string?
  tags: object?
}

@description('Resource groups selected in Skyforge.')
param instances resourceGroupConfigType[]

@description('Fallback Azure region shared by this infrastructure package.')
param defaultLocation string

@description('Tags shared by this infrastructure package.')
param tags object = {}

resource resourceGroups 'Microsoft.Resources/resourceGroups@2025-04-01' = [for instance in instances: {
  name: instance.resourceName
  location: instance.?location ?? defaultLocation
  managedBy: instance.?managedBy
  tags: union(tags, instance.?tags ?? {}, empty(instance.?purpose ?? '') ? {} : {
    purpose: instance.?purpose ?? ''
  })
}]

output configurations resourceGroupConfigType[] = instances
output names string[] = map(resourceGroups, group => group.name)
