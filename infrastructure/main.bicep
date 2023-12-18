param location string
param prefix string
param vnetSettings object = {
  addressPrefixes: [
    '10.0.0.0/19'
  ]
  subnets: [
    {
      name: 'subnet1'
      addressPrefix: '10.0.0.0/21'
    }
    {
      name: 'acaAppSubnet'
      addressPrefix: '10.0.8.0/21'
    }
    {
      name: 'acaControlPlanSubnet'
      addressPrefix: '10.0.16.0/21'
    }
  ]
}
param containerVersion string

module core 'core.bicep' = {
  name: 'core'
  params: {
    location: location
    prefix: prefix
    vnetSettings: vnetSettings
  }
}

resource secretKeyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: 'lmbdvault01'
}

module aca 'aca.bicep' = {
  name: 'aca'
  dependsOn: [
    core
  ]
  params: {
    containerRegistryName: core.outputs.ContainerRegistryName
    containerRegistryPassword: secretKeyVault.getSecret(core.outputs.ContainerRegistrySecret)
    containerRegistryUsername: core.outputs.ContainerRegistryUsername
    containerVersion: containerVersion
    cosmosAccountName: core.outputs.CosmosAccountName
    cosmosContainerName: core.outputs.ComosSqlContainerName
    cosmosDbName: core.outputs.CosmosDbName
    location: location
    prefix: prefix
    vNetId: core.outputs.vNetId
    vNetName: core.outputs.vnetName
  }
}
