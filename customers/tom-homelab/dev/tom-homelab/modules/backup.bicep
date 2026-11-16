// Azure Backup — validated deployable Recovery Services vault composition
targetScope = 'resourceGroup'

type protectedWorkloadEntryType = {
  workloadType: string?
  resourceRef: string
  policyRef: string?
}

type backupPolicyEntryType = {
  name: string
  scheduleFrequency: string?
  instantRestoreRetentionDays: string?
  dailyRetentionDays: string?
  weeklyRetentionWeeks: string?
  monthlyRetentionMonths: string?
  yearlyRetentionYears: string?
  timezone: string?
}

type vaultRoleAssignmentEntryType = {
  principalId: string
  roleName: string
}

type identityAssignmentEntryType = {
  type: ('SystemAssigned' | 'UserAssigned')
  identityRef: string?
  identityResourceGroup: string?
  identitySubscriptionId: string?
  roles: string?
}

type serviceConfigType = {
  resourceName: string?
  resourceGroupRef: string?
  vaultType: ('RecoveryServicesVault' | 'BackupVault')?
  redundancyAndCrossRegionRestore: ('LRS' | 'ZRS' | 'GRS' | 'GRS+CRR')?
  softDeleteEnabled: bool?
  softDeleteRetentionDays: string?
  immutabilityState: ('Disabled' | 'Unlocked' | 'Locked')?
  protectedWorkloads: protectedWorkloadEntryType[]?
  policies: backupPolicyEntryType[]?
  muaEnabled: bool?
  resourceGuardRef: string?
  identityAssignments: identityAssignmentEntryType[]?
  cmkEnabled: bool?
  cmkKeyVaultKeyUri: string?
  vaultRoleAssignments: vaultRoleAssignmentEntryType[]?
  diagnosticWorkspaceRef: string?
  alertEmailRecipients: string?
  restoreTestFrequency: string?
  privateConnectivity: bool?
}

@description('Azure Backup instances selected and prerequisite-validated in Skyforge.')
param instances serviceConfigType[] = []

@description('Azure region shared by this infrastructure package.')
param location string

@description('Tags shared by this infrastructure package.')
param tags object = {}

var storageRedundancyByCode = {
  LRS: 'LocallyRedundant'
  ZRS: 'ZoneRedundant'
  GRS: 'GeoRedundant'
  'GRS+CRR': 'GeoRedundant'
}

var resolvedInstances = [for (instance, index) in instances: {
  name: empty(instance.?resourceName ?? '') ? 'rsv-${uniqueString(resourceGroup().id, string(index))}' : (instance.?resourceName ?? '')
  vaultType: instance.?vaultType ?? 'RecoveryServicesVault'
  standardTierStorageRedundancy: storageRedundancyByCode[instance.?redundancyAndCrossRegionRestore ?? 'GRS+CRR']
  crossRegionRestore: (instance.?redundancyAndCrossRegionRestore ?? 'GRS+CRR') == 'GRS+CRR' ? 'Enabled' : 'Disabled'
  softDeleteState: (instance.?softDeleteEnabled ?? true) ? 'Enabled' : 'Disabled'
  softDeleteRetentionPeriodInDays: int(instance.?softDeleteRetentionDays ?? '14')
  immutabilityState: instance.?immutabilityState ?? 'Unlocked'
  // Private connectivity closes public access; the vault is then reached through its private endpoint (AzureBackup).
  publicNetworkAccess: (instance.?privateConnectivity ?? false) ? 'Disabled' : 'Enabled'
}]

// Backup vault (Microsoft.DataProtection/backupVaults) is a separate resource provider and stays review-only for now.
var recoveryServicesVaultInstances = filter(resolvedInstances, instance => instance.vaultType == 'RecoveryServicesVault')

resource vaults 'Microsoft.RecoveryServices/vaults@2026-05-01' = [for instance in recoveryServicesVaultInstances: {
  name: instance.name
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: instance.publicNetworkAccess
    redundancySettings: {
      standardTierStorageRedundancy: instance.standardTierStorageRedundancy
      crossRegionRestore: instance.crossRegionRestore
    }
    securitySettings: {
      softDeleteSettings: {
        softDeleteState: instance.softDeleteState
        softDeleteRetentionPeriodInDays: instance.softDeleteRetentionPeriodInDays
      }
      immutabilitySettings: {
        state: instance.immutabilityState
      }
    }
  }
}]

output configurations serviceConfigType[] = instances
