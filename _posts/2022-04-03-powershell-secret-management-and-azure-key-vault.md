---
layout: post
title: PowerShell Secret Management and Azure Key Vault
date: 2022-04-03 09:06 +0200
categories: [Secrets Management, Azure Key Vault]
tags: [PowerShell]
---

Today I want to show you how easy It is to access Azure Key Vault with the Secret Management
module from the PowerShell Team at Microsoft.

## What is the Secret Management Module?

Today every Secret Vault owner has It's own way of accessing stored secrets.
One uses a cli tool another one uses a Rest API call and another one uses PowerShell.

To make that consistent Microsoft introduced the Microsoft.PowerShell.SecretManagement module.
If your secret product is registered with the module you can use the CmdLets of the Secret Management module to access the secrets.

The CmdLets are:

- Set-Secret
- Get-SecretInfo
- Get-SecretVault
- Register-SecretVault
- Remove-Secret
- Set-Secret
- Set-SecretInfo
- Set-SecretVaultDefault
- Test-SecretVault
- Unregister-SecretVault

To learn more you can read the official blog post [here](https://devblogs.microsoft.com/powershell/secretmanagement-and-secretstore-are-generally-available/){:target="_blank"}

If you want to watch videos you can watch [my video](https://www.youtube.com/watch?v=qEBdawa67Q8) from the PowerShell Usergroup (German) or Mike Kanakoses [video](https://www.youtube.com/watch?v=vEniQPooUSs) (english) where this is shown in more detail.

## Deploy resources with Powershell

For our example we need an Azure AD service principal and the Azure KeyVault.
So let us create that with PowerShell

```powershell
# Connect to your Azure Subscription and change to the right subscription
Connect-AzAccount

# Create an Azure AD Service Principal
$sp = New-AzADServicePrincipal -DisplayName "AzureKeyVault"

# Create a Azure AD Service Principal Secret
$StartDate = Get-Date
$EndDate = (Get-Date).AddYears(1)

$secret = Get-AzADApplication -ApplicationId $sp.AppId |
    New-AzADAppCredential -StartDate $StartDate -EndDate $EndDate

# Assing Service Principal Contributor rights on the resource group
# where Azure Key Vault was created before
$splat = @{
    ObjectId           = $sp.Id
    RoleDefinitionName = "Contributor"
    Scope              ='/subscriptions/<subscriptionid>/resourceGroups/<resourcegroup name>'
}

New-AzRoleAssignment @splat

# Create the Azure Key Vault
New-AzResourceGroup -Name "blog-rg" -Location "West Europe"

$splat = @{
    Name              = "itguysecretkeyvault"
    ResourceGroupName = 'blog-rg'
    Location          = 'West Europe'
}

$kv = New-AzKeyVault @splat

# Create the Azure Key Vault secret
$splat = @{
    String      = "Start.12345"
    AsPlainText = $true
    Force       = $true
}
$pwd = ConvertTo-SecureString @splat

$splat = @{
    VaultName   = $kv.VaultName
    Name        = "MySecret"
    SecretValue = $pwd
}
Set-AzKeyVaultSecret @splat

# Add the Service Principal to the Access policy of Azure Key Vault
$splat = @{
    VaultName            = $kv.VaultName
    ResourceGroupName    = 'blog-rg'
    PermissionsToSecrets = @('get','list')
    ObjectId             = $sp.Id
}
Set-AzKeyVaultAccessPolicy @splat
```

## Login to Azure with the Service Principal

```powershell

$appid = $sp.AppId
$key = $secret.SecretText
$directoryId = $sp.AppOwnerOrganizationId
$pass = ConvertTo-SecureString -String $key -AsPlainText -Force

$splat = @{
    TypeName     = System.Management.Automation.PSCredential
    ArgumentList = "$appid" , $pass
}

$cred = New-Object @splat

Connect-AzAccount -Credential $cred -ServicePrincipal -TenantId $Directoryid

```

## Register Azure Key Vault with Secret Management

To get the Vault extension that is needed for accessing Azure Key Vault with the Secret Management module you need the Az.KeyVault module.

```powershell
Install-Module Az.KeyVault
```

Now we can register our Azure Key Vault with the Secret Management Module

```powershell

Register-SecretVault -Module Az.KeyVault -Name blogkv -VaultParameters @{
    AZKVaultName = $kv.VaultName
    SubscriptionId = <Your Subscriptionid>
}

```

If you want to check if your vault is registered correctly these CmdLets are useful for that

```powershell
# Check if it was created
Get-SecretVault

# Check if you can access it
Test-SecretVault
```

## Retrieve Secret with SecretMangement module

```powershell
# Get secret in clear Text
Get-Secret -Name MySecret -Vault blogkv -AsPlainText

# Get secret as securestring
Get-Secret -Name MySecret -Vault blogkv
```

I hope It was informative for you. That's It for this blog post.