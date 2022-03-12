---
title: Accessing Azure Key Vault Through Azure Automation
date: 2022-03-12 19:13 +0100
categories: [Azure, Azure Automation]
tags: [PowerShell]
---

## The Challange
Today I tried to access an Azure Key Vault secret inside of an Azure Automation Runbook.
I don't want to use an Azure Service Prinicipal (Run As Account) because you have to handle the
secret rotation by yourself.

I don't want to mark the date in my calender or do the rotation manually.

So I created a Managed Identity. If you use Azure services like Azure Automation a Managed identity (System Assigned)
will be created for you automatically.

## Managed Identities
There are two types of Managed Identies:

- System Assigned
- User Assigned

If you want to learn more about the differences between them [here](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview){:target="_blank"} is the Microsoft Docs article.

So let's start by creating the needed Azure resources with PowerShell.

## Deploy Resources with PowerShell
```powershell
# Resource Group
$splat = @{
    Name     = "blog-rg"
    Location = "West Europe"
}
$rg = New-AzResourceGroup @splat

# User Assigned Managed Identity
$splat = @{
    ResourceGroupName = $rg.ResourceGroupName
    Name              = "AzKeyVaultAccess"
    Location          = "West Europe"
}
$mi = New-AzUserAssignedIdentity @splat

# Azure Key Vault
$splat = @{
    Name              = "itguyblogkeyvault"
    ResourceGroupName = $rg.ResourceGroupName
    Location          = "West Europe"
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

# Add the User Assigned Managed Identity to the Access policy of Azure Key Vault
$splat = @{
    VaultName            = $kv.VaultName
    ResourceGroupName    = $rg.ResourceGroupName
    PermissionsToSecrets = @('get','list')
    ObjectId             = $mi.PrincipalId
}
Set-AzKeyVaultAccessPolicy @splat

# Azure Automation Account
$splat = @{
    Name               = "itguyautomationaccount"
    Location           = "WestEurope"
    ResourceGroupName  = $rg.ResourceGroupName
}
New-AzAutomationAccount @splat

# Get the Client id of the user assigned managed identity
# we need that for later
$ClientId = $mi.ClientId

Write-Output "The ClientId that you have to put into the Azure Automation Runbook is: $ClientId"
```

## Challanges with PowerShell 7.1 Preview
We now have the foundation of all the resources we need. Now let's create the Azure Automation Runbook
to test if the connection between Azure Automation and Azure Key Vault is working.

You can also create an Azure Automation Runbook through [PowerShell](https://docs.microsoft.com/en-us/powershell/module/az.automation/new-azautomationrunbook?view=azps-7.3.0){:target="_blank"}.
At the moment of writing Azure PowerShell version 7.3.0 was not capable of creating an Azure Automation runbooks with the PowerShell 7.1 (preview) runtime version.

So let's do that visually.

## Create the Azure Automation Runbook

Navigate to your Azure Automation Account and click on Runbooks to create a new runbook.

![Runbook1](/assets/pictures/2022-03-12/Runbook1.png)

## Add Code to the Runbook

Add the following Code to the Azure Automation PowerShell runbook

```powershell
$splat = @{
    Identity = $true
    AccountId = "<client id of your user assigned managed identity>"
}
Connect-AzAccount @splat
Get-AzKeyVaultSecret -VaultName itguyblogkeyvault
```

Click Save and then Publish.

Start the runbook.

If everything went correctly you should see your secret in the output window

![Runbook2](/assets/pictures/2022-03-12/Runbook2.png)

That's it for this post