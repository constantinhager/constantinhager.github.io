---
layout: post
title: Azure Arc with AutomatedLab
date: 2022-11-12 16:22 +0100
categories: [Hybrid]
tags: [Azure Arc, PowerShell, AutomatedLab]
---

In this blog post i will show you how easy it is to create an Azure Arc test environment with AutomatedLab.

But what is Azure Arc and AutomatedLab?

AutomatedLab is a PowerShell module where you can create easy and very complicated lab environments.
You can learn more about AutomatedLab [here](https://automatedlab.org/en/latest/){:target="_blank"}

With Azure Arc It is possible to use the Azure services in you On-Premises datacenter or in any other
Cloud that is not Azure. You can learn more about Azure Arc [here](https://azure.microsoft.com/en-us/products/azure-arc/#overview){:target="_blank"}

## How to onboard Server to Azure Arc

You can onboard for example Servers to Azure Arc in two ways:

1. Use the script to onboard one server
2. Use a script to onboard multiple servers

<blockquote class="prompt-tip">
    In our case we need to use the second approach because in the
    first approach we have to authenticate interactively.
</blockquote>

But first we have to register multiple Azure Resource Provider. Use
the following code snipped for this

<blockquote class="prompt-tip">
    The following script snippets assumed that you have already
    connected with your Azure Subscription
</blockquote>

```powershell
# Register the following Azure Providers
# Microsoft.HybridCompute
Register-AzResourceProvider -ProviderNamespace Microsoft.Hybridcompute
# Microsoft.GuestConfiguration
Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration
# Microsoft.HybridConnectivity
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity
```

Now we need to create an Azure Service Principal.

```powershell
# Get Subscription Id
$subid = Get-AzSubscription -SubscriptionName 'Name of your subscription' | Select-Object -ExpandProperty Id

# Create Resource Group for the Windows Server Arc Resource
$rg = New-AzResourceGroup -Name 'ArcResources-rg' -Location 'westeurope'

# Create Service Principal
$sp = New-AzADServicePrincipal -DisplayName 'ArcOnboarding'

# Remove the newly created secret
$appcred = Get-AzADAppCredential -DisplayName $sp.DisplayName
Get-AzADApplication -DisplayName $sp.DisplayName | Remove-AzADAppCredential -KeyId $appcred.KeyId

# Create a Secret inside of the Service Principal
$StartDate = Get-Date
$EndDate = (Get-Date).AddDays(1)

$pscredobj = New-Object Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential
$pscredobj.DisplayName = 'ArcOnboardingSecret'
$pscredobj.StartDateTime = $StartDate
$pscredobj.EndDateTime = $EndDate

$secret = New-AzADAppCredential -DisplayName $sp.DisplayName -PasswordCredentials $pscredobj

# Add RBAC for Azure Connected Machine Onboarding, Kubernetes Cluster - Azure Arc Onboarding to Resourcegroup
$Parameters = @{
    RoleDefinitionName = 'Azure Connected Machine Onboarding'
    ApplicationId      = $sp.AppId
    ResourceGroupName  = $rg.ResourceGroupName
}
New-AzRoleAssignment @Parameters

$Parameters = @{
    RoleDefinitionName = 'Kubernetes Cluster - Azure Arc Onboarding'
    ApplicationId      = $sp.AppId
    ResourceGroupName  = $rg.ResourceGroupName
}
New-AzRoleAssignment @Parameters

```

All the prerequisites are now there for starting the onboarding process to Azure Arc.

## Create Lab environment with AutomatedLab

```powershell
New-LabDefinition -Name AzureArc -DefaultVirtualizationEngine HyperV

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'          = 2048MB
}

Set-LabInstallationCredential -Username Install -Password 'your password'

$Parameters = @{
    Name             = 'Default Switch'
    HyperVProperties = @{
        SwitchType  = 'External'
        AdapterName = 'Ethernet'
    }
}
Add-LabVirtualNetworkDefinition @Parameters

Add-LabMachineDefinition -Name 'ArcVM' -Network 'Default Switch'

Install-Lab

Show-LabDeploymentSummary -Detailed
```

## Add Server to Azure Arc

To add the server to Azure Arc the Azure Connected machine agent needs to be installed. This can be done by the following script:

```powershell
$AppId = $sp.AppId
$SecretText = $secret.SecretText
$ResourceGroupName = $rg.ResourceGroupName
$TenantId = $sp.AppOwnerOrganizationId

function Add-LabMachineToAzureArc {
    param(
        [Parameter()]
        [string]
        $ClientId,

        [Parameter()]
        [string]
        $Secret,

        [Parameter()]
        [string]
        $SubscriptionId,

        [Parameter()]
        [string]
        $ResourceGroup,

        [Parameter()]
        [string]
        $TenantId,

        [Parameter()]
        [string]
        $Location = 'West Europe',

        [Parameter()]
        [string]
        $AuthType = 'principal'
    )

    try {
        $servicePrincipalClientId = "$ClientId"
        $servicePrincipalSecret = "$Secret"
        $env:SUBSCRIPTION_ID = "$SubscriptionId"
        $env:RESOURCE_GROUP = "$ResourceGroup"
        $env:TENANT_ID = "$TenantId"
        $env:LOCATION = "$Location"
        $env:AUTH_TYPE = "$AuthType"
        $env:CORRELATION_ID = '2e23374d-21c1-424f-855e-e3f84ff4c89e'
        $env:CLOUD = 'AzureCloud'

        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        Invoke-WebRequest -Uri 'https://aka.ms/azcmagent-windows' -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1"
        & "$env:TEMP\install_windows_azcmagent.ps1"
        & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id "$servicePrincipalClientId" --service-principal-secret "$servicePrincipalSecret" --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" --cloud "$env:CLOUD" --tags "Datacenter='your datacenter',City=your city,StateOrDistrict=add your information,CountryOrRegion=your country" --correlation-id "$env:CORRELATION_ID"
    } catch {
        $logBody = @{
            subscriptionId = "$env:SUBSCRIPTION_ID"
            resourceGroup  = "$env:RESOURCE_GROUP"
            tenantId       = "$env:TENANT_ID"
            location       = "$env:LOCATION"
            correlationId  = "$env:CORRELATION_ID"
            authType       = "$env:AUTH_TYPE"
            messageType    = $_.FullyQualifiedErrorId
            message        = "$_"
        }
        Invoke-WebRequest -Uri 'https://gbl.his.arc.azure.com/log' -Method 'PUT' -Body ($logBody | ConvertTo-Json) | Out-Null
        Write-Host -ForegroundColor red $_.Exception
    }
}

$param = @{
    ActivityName = 'Onboarding into Azure Arc'
    Variable = (Get-Variable AppId),
    (Get-Variable SecretText),
    (Get-Variable subid),
    (Get-Variable ResourceGroupName),
    (Get-Variable TenantId)
    Function     = (Get-Command Add-LabMachineToAzureArc)
    ComputerName = 'ArcVM'
    ScriptBlock  = {
        $Parameters = @{
            ClientId       = $AppId
            Secret         = $SecretText
            SubscriptionId = $subid
            ResourceGroup  = $ResourceGroupName
            TenantId       = $TenantId
        }
        Add-LabMachineToAzureArc @Parameters
    }
}

Invoke-LabCommand @param
```

If this was executed successfully the Server is now visible in Azure Arc.
Navigate to the Azure Portal -> All Services -> Azure Arc -> Infrastructure -> Servers.

See you next time. Happy Azure Arc enabling.