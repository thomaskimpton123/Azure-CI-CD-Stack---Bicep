// Managed identity RBAC role assignments — nested module invoked once per identity
// Dispatches each role assignment to subscription scope directly, or to a resource-group-scoped nested module.
targetScope = 'subscription'

type roleAssignmentEntryType = {
  roleName: string
  scopeType: ('subscription' | 'resourceGroup')
  resourceGroupName: string?
  subscriptionId: string?
}

@description('Principal (object) ID of the user-assigned managed identity being granted these roles.')
param principalId string

@description('Role assignments to create for this identity.')
param roleAssignments roleAssignmentEntryType[] = []

// Built-in role definition GUIDs for the roles offered in Skyforge.
var builtInRoleDefinitionIds = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Secrets Officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
  'Key Vault Certificates Officer': 'a4417e6f-fecd-4de8-b567-7b0420556985'
  'Key Vault Crypto Officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  'Key Vault Crypto User': '12338af0-0e69-4776-bea7-57ae8d297424'
  'Key Vault Reader': '21090545-7ca7-4776-b22c-e363652d74d2'
  'Storage Blob Data Contributor': 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  'Storage Blob Data Reader': '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  'Storage Blob Data Owner': 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  'Managed Identity Operator': 'f1a07417-d97a-45cb-824c-7a7467783830'
  'Managed Identity Contributor': 'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59'
  'Monitoring Reader': '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
  'Monitoring Contributor': '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  'Cognitive Services OpenAI User': '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  'Cognitive Services User': 'a97b65f3-24c7-4388-baec-2e87135dc908'
  'Azure AI Developer': '64702f94-c441-49e6-a78b-ef80e0188fee'
  'Search Index Data Contributor': '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  'Search Index Data Reader': '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  'Search Service Contributor': '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  'Cognitive Services OpenAI Contributor': 'a001fd3d-188f-4b5d-821b-7da978bf7442'
  AcrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  AcrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  'Storage Queue Data Contributor': '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  'Storage Table Data Contributor': '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  'Log Analytics Reader': '73c42c96-874c-492b-b04d-ab87d138a893'
  'Log Analytics Contributor': '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  'Monitoring Metrics Publisher': '3913510d-42f4-4e42-8a64-420c390055eb'
  'Website Contributor': 'de139f84-1756-47ae-9be6-808fbbe84772'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  'Azure Service Bus Data Owner': '090c5cfd-751d-490a-894a-3ce6f1109419'
  'Azure Service Bus Data Sender': '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  'Azure Service Bus Data Receiver': '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  'Azure Event Hubs Data Owner': 'f526a384-b230-433a-b45c-95f59c4a2dec'
  'Azure Event Hubs Data Sender': '2b629674-e913-4c01-ae53-ef4638d8f975'
  'Azure Event Hubs Data Receiver': 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
  'EventGrid Data Sender': 'd5a91429-5739-47e2-a06b-3470a27159e7'
  'SignalR App Server': '420fcaa2-552c-430f-98ca-3264be4806c7'
  'SignalR Service Owner': '7e4f1700-ea5a-4f59-8f37-079cfe29dce3'
  'Azure Relay Owner': '2787bf04-f1f5-4bfe-8383-c8a24483ee38'
  'Azure Relay Sender': '26baccc8-eea7-41f1-98f4-1762cc7f685d'
  'Azure Relay Listener': '26e0b698-aa6d-4085-9386-aadae190014d'
  'App Configuration Data Owner': '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'
  'App Configuration Data Reader': '516239f1-63e1-4d78-a4de-a74fb236a071'
  'Azure Kubernetes Service RBAC Cluster Admin': 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
  'Azure Kubernetes Service RBAC Admin': '3498e952-d568-435e-9b2c-8d77e338d7f7'
  'Azure Kubernetes Service RBAC Writer': 'a7ffa36f-339b-4b5c-8bdf-e2c188b2c0eb'
  'Azure Kubernetes Service RBAC Reader': '7f6c6a51-bcf8-42ba-9220-52d62157d7db'
  'Azure Kubernetes Service Cluster User Role': '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
  'API Management Service Contributor': '312a565d-c81f-4fd8-895a-4e21e48d571c'
  'API Management Service Reader Role': '71522526-b88f-4d52-b57f-d31fc3546d0d'
  'Data Factory Contributor': '673868aa-7521-48a0-acc6-0f60742d39f5'
  Owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  'Azure AI User': '53ca6127-db72-4b80-b1b0-d745d6d5456d'
  'Azure AI Project Manager': 'eadc314b-1a2d-4efa-be10-5d325db5065e'
  'Cognitive Services Contributor': '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
  'AzureML Data Scientist': 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  'AzureML Compute Operator': 'e503ece1-11d0-4e8e-8e2c-7a6c3bf38815'
  'Automation Operator': 'd3881f73-407a-4167-8283-e981cbba0404'
  'Automation Contributor': 'f353d9bd-d4a6-484e-a77a-8050b599b867'
  'Automation Job Operator': '4fe576fe-1146-4730-92eb-48519fa6bf9f'
  'Automation Runbook Operator': '5fb5aef8-1081-4b8e-bb16-9d5d0385bab5'
  'Microsoft Sentinel Reader': '8d289c81-5878-46d4-8554-54e1e3d8b5cb'
  'Microsoft Sentinel Responder': '3e150937-b8fe-4cfb-8069-0eaf05ecd056'
  'Microsoft Sentinel Contributor': 'ab8e14d6-4a74-4a29-9ba8-549422addade'
  'Microsoft Sentinel Automation Contributor': 'f4c81013-99ee-4d62-a7ee-b3f1f648599a'
  'Resource Policy Contributor': '36243c78-bf99-498c-9df9-86d9f8d28608'
  'Logic App Contributor': '87a39d53-fc1b-424a-814c-f7e04687dc9e'
  'Logic App Operator': '515c2055-d9d4-4321-b1b9-bd0c9a0f79fe'
}

resource subscriptionRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in roleAssignments: if (assignment.scopeType == 'subscription') {
  name: guid(subscription().id, principalId, assignment.roleName)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtInRoleDefinitionIds[assignment.roleName])
    principalType: 'ServicePrincipal'
  }
}]

module resourceGroupRoleAssignments 'managed-identity-role-assignment-rg.bicep' = [for assignment in roleAssignments: if (assignment.scopeType == 'resourceGroup') {
  scope: resourceGroup(assignment.?subscriptionId ?? subscription().subscriptionId, assignment.?resourceGroupName ?? '')
  params: {
    principalId: principalId
    roleName: assignment.roleName
  }
}]
