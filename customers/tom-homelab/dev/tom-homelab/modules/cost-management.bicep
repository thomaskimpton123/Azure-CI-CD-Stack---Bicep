// Cost Management budgets for the subscription this package deploys to.
targetScope = 'subscription'

type serviceConfigType = {
  resourceName: string
  @description('Values resolved by Skyforge.')
  deploy: object
}

@description('Cost Management instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
#disable-next-line no-unused-params
param location string

@description('Tags shared by this infrastructure package.')
#disable-next-line no-unused-params
param tags object = {}

@description('First day of the month the budgets start; defaults to the current month.')
param startDate string = utcNow('yyyy-MM-01')

resource budgets 'Microsoft.Consumption/budgets@2024-08-01' = [for budget in flatten(map(instances, instance => instance.deploy.budgets)): {
  name: budget.name
  properties: {
    category: 'Cost'
    amount: budget.amount
    timeGrain: budget.timeGrain
    timePeriod: {
      startDate: startDate
    }
    notifications: budget.notifications
  }
}]

output configurations serviceConfigType[] = instances
