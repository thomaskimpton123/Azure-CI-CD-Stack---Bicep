using './tenant.bicep'

// Subscriptions placed under a management group. IDs not known at intake are read from environment variables when deploying.
var subscriptions = {
  'app-dev': readEnvironmentVariable('AZ_SUBSCRIPTION_APP_DEV')
  management: readEnvironmentVariable('AZ_SUBSCRIPTION_MANAGEMENT')
  connectivity: readEnvironmentVariable('AZ_SUBSCRIPTION_CONNECTIVITY')
  identity: readEnvironmentVariable('AZ_SUBSCRIPTION_IDENTITY')
}

param managementGroups = [
  {
    name: 'mg-alz'
    displayName: 'Azure Landing Zones'
    level: 1
  }
  {
    name: 'mg-platform'
    displayName: 'Platform'
    parent: 'mg-alz'
    level: 2
  }
  {
    name: 'mg-landing-zones'
    displayName: 'Landing zones'
    parent: 'mg-alz'
    level: 2
  }
  {
    name: 'mg-corp'
    displayName: 'Corp'
    parent: 'mg-landing-zones'
    level: 3
  }
  {
    name: 'mg-online'
    displayName: 'Online'
    parent: 'mg-landing-zones'
    level: 3
  }
  {
    name: 'mg-sandbox'
    displayName: 'Sandbox'
    parent: 'mg-alz'
    level: 2
  }
]

param subscriptionPlacements = [
  {
    subscriptionId: subscriptions['app-dev']
    managementGroup: 'mg-corp'
  }
  {
    subscriptionId: subscriptions.management
    managementGroup: 'mg-platform'
  }
  {
    subscriptionId: subscriptions.connectivity
    managementGroup: 'mg-platform'
  }
  {
    subscriptionId: subscriptions.identity
    managementGroup: 'mg-platform'
  }
]
