param location string
param prefix string
param vNetId string
param containerRegistryName string
param containerRegistryUsername string
@secure()
param containerRegistryPassword string
param containerVersion string
param cosmosAccountName string
param cosmosDbName string
param cosmosContainerName string


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: '${prefix}-la-workspace'
  location: location
  // properties: {
    // sku: {
    //  name: 'Standard'
    // }
  // }
} 

resource env 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${prefix}-container-env'
  location: location
  kind: 'containerenvironment'
  properties: {
    environmentType: 'managed'
    internalLoadBalancerEnabled: false
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listkeys().primarySharedKey
      }
    }
    containerAppsConfiguration: {
      appSubnetResourceId: '${vNetId}/subnets/acaAppSubnet'
      controlPlaneSubnetResourceId: '${vNetId}/subnets/acaControlPlaneSubnet'
    }
  }
 }

 resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' existing = {
  name: cosmosAccountName
 }

 var cosmosDbKey = cosmosDbAccount.listKeys().primaryMasterKey

 resource apiApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${prefix}-api-container'
  location: location
  kind: 'containerapp'
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          username: containerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      ingress: {
        external: true
        targetPort: 3000
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/k8se/quickstart:${containerVersion}'
          name: 'lambdaapi'
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
      }
      dapr: {
        enabled: true
        appPort: 3000
        appId: 'lambaapi'
         components: [
          {
            name: 'statestore'
            type: 'state.azure.cosmosdb'
            version: 'v1'
            metadata: [
              {
                name: 'url'
                value: 'https://${cosmosAccountName}.documents.azure.com:443/'
              }
              {
                name: 'database'
                value: cosmosDbName
              }
              {
                name: 'collection'
                value: cosmosContainerName
              }
              {
                name: 'masterkey'
                value: cosmosDbKey
              }
            ]
          }
         ]
      }
    }
  }
}
