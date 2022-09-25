---
layout: post
title: Assign Microsoft Graph Permission to a Managed Identity
date: 2022-09-25 11:11 +0200
categories: [Azure]
tags: [PowerShell, Microsoft Graph, Managed Identities]
---

After my injury I'm now back with another blog post.

In my previous blog post I showed you how to assign Microsoft Graph Role assignments
to a System Assiged Managed identity with the Azure CLI.

This time I want to blog about how to assign Microsoft Graph permissions to a User / System Assigned Managed Identity with PowerShell.

At the time of this writing there is no graphical user interface for assigning Microsoft Graph permissions for
managed identities, so I created a little PowerShell Helper function for you to do that.

But First Let us create a Resource Group and a User Assigned Managed Identity with the following code

```powershell
New-AzResourceGroup -Name Blog -Location 'West Europe'
$Identity = New-AzUserAssignedIdentity -ResourceGroupName 'Blog' -Name 'blogidentity'
```

After that we create some variables

```powershell
# Your tenant id (in Azure Portal, under Azure Active Directory -> Overview )
$TenantID = 'Your Tenant Id'

# Check the Microsoft Graph documentation for the permission you need for the operation. These are just samples.
$PermissionName = @('DeviceManagementServiceConfig.Read.All', 'Device.Read.All', 'Directory.ReadWrite.All', 'Device.ReadWrite.All')
```

<blockquote class="prompt-tip">
    You need the modules of Microsoft.Graph installed on your machine.
</blockquote>

<blockquote class="prompt-tip">
You need to authenticate against Microsoft Graph. Please use a Azure Active Directory user who has the appropriate permissions.
</blockquote>

Here is the PowerShell function that is doing the role assignment

```powershell
function Add-CHManagedIdentityRoleAssignment {

    <#
        .SYNOPSIS
           Assigns Microsoft Graph Permissions to a User / System Assigned Managed identity.
        .DESCRIPTION
           Assigns Microsoft Graph Permissions to a User / System Assigned Managed identity.

           The function checks if the App Role exists in Microsoft Graph.
           The function checks if the App Role that you want to assign to the Managed Identity
           is already assigned. If It is it will print out a appropriate message.
        .EXAMPLE
           $splat = @{
               GraphPermission     = $PermissionName
               ManagedIdentityName = $Identity.Name
               ServicePrincipalId  = $Identity.PrincipalId
               TenantID            = $TenantID
           }
           Add-CHManagedIdentityRoleAssignment @splat
           Assigns Microsoft Graph Permissions to a User / System Assigned Managed identity.
        .NOTES
           Author: Constantin Hager
           Date: 2022-25-09
    #>

    param(
        [Parameter(Mandatory)]
        [string[]]
        $GraphPermission,

        [Parameter(Mandatory)]
        [string]
        $ManagedIdentityName,

        [Parameter(Mandatory)]
        [string]
        $ServicePrincipalId,

        [Parameter(Mandatory)]
        [string]
        $TenantID
    )
    $GraphAppId = '00000003-0000-0000-c000-000000000000'

    $splat = @{
        TenantId = $TenantID
        Scopes   = 'application.readwrite.all', 'Approleassignment.readwrite.all', 'Directory.readwrite.all'
    }
    Connect-MgGraph @splat

    $splat = @{
        Search           = "DisplayName:$ManagedIdentityName"
        ConsistencyLevel = 'eventual'
    }
    $MSI = Get-MgServicePrincipal @splat

    $splat = @{
        Search           = ('"appId:{0}"' -f $GraphAppId)
        ConsistencyLevel = 'eventual'
    }
    $GraphServicePrincipal = Get-MgServicePrincipal @splat

    foreach ($Permission in $PermissionName) {
        $AppRole = $GraphServicePrincipal.AppRoles |
        Where-Object { $_.Value -eq $Permission -and $_.AllowedMemberTypes -contains 'Application' }

        if ($null -eq $AppRole) {
            Write-Output "No Approle found in Microsoft Graph with Permission name $Permission"
            Continue
        } else {

            $IsAppRoleAssigned = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId |
            Where-Object { $_.AppRoleId -eq $AppRole.Id }

            if ($null -eq $IsAppRoleAssigned) {
                Write-Output "Assign $Permission to $($MSI.DisplayName)."
                $appRoleAssignment = @{
                    'principalId' = $MSI.Id
                    'resourceId'  = $GraphServicePrincipal.Id
                    'appRoleId'   = $AppRole.Id
                }

                New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $MSI.Id -BodyParameter $appRoleAssignment
            } else {
                Write-Output "$Permission on $($MSI.DisplayName) exists already."
                Continue
            }
        }
    }
}
```

You can execute the function now

```powershell
$splat = @{
    GraphPermission     = $PermissionName
    ManagedIdentityName = $Identity.Name
    ServicePrincipalId  = $Identity.PrincipalId
    TenantID            = $TenantID
}
Add-CHManagedIdentityRoleAssignment @splat
```

If you want to check the role assignment with PowerShell

```powershell
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $Identity.PrincipalId
```

If you want to check the role assignment with the Azure Portal

Navigate to Azure Active Directory -> Enterprise Applications -> Application type == Managed Identities.

Select your Managed Identity and click on permissions.

In both cases you can see the app role assignments that we did earlier. You can now
use your managed identities to make calls against the Microsoft Graph API.

See you next time. Happy coding.