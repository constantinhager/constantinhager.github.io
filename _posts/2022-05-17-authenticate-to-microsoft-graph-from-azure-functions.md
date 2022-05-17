---
layout: post
title: Authenticate to Microsoft Graph from Azure Functions
date: 2022-05-17 11:03 +0200
categories: [Azure]
tags: [Azure Functions, Microsoft Graph]
---

In this blog post I will show you how to authenticate to Microsoft Graph inside of a PowerShell Azure Function.
We will use a System Assigned Managed identity for authentication.

To enable a System Assigned Managed identity inside of an Azure Function go to the Identity section, switch the
status to on and Save. The result should be like this:

![System Assigned Managed Identity](/assets/pictures/2022-05-17/SystemAssignedManagedIdentity.png)

For Authentication to Microsoft Graph we can use the following environment variables:

- **IDENTITY_ENDPOINT / MSI_ENDPOINT**: The URL to call to get a token for the Managed Service identity
- **IDENTITY_HEADER**: The object id for the Managed Service identity in Azure AD

Now we can use the following PowerShell code to authenticate to Microsoft Graph and get an access token:

```powershell
$resource = 'https://graph.microsoft.com'

$endpoint = $env:IDENTITY_ENDPOINT
$header = $env:IDENTITY_HEADER
$apiVersion = '2019-08-01'

$headers = @{ 'X-Identity-Header' = $header }

$url = "$($endpoint)?api-version=$apiVersion&resource=$resource"

$response = Invoke-RestMethod -Method Get
$accessToken = $response.access_token
```

(optional) To use the MgGraph CmdLets inside of the Azure Function use the following PowerShell code:

<blockquote class="prompt-tip">
    If you want to use the MgGraph CmdLets inside of an Azure Function add the needed modules to the requirements.psd1 file.
</blockquote>

```powershell
$authHeader = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + $accessToken
}

Connect-MgGraph -AccessToken $accessToken
```

<blockquote class="prompt-tip">
    If you do not need to Authenticate to Azure through Managed Identity comment out the if statement in profile.ps1.
</blockquote>

Now authenticated to Microsoft Graph you cannot do anything because the System Assigned managed identity has no
rights inside of Microsoft Graph.

To assign them I have found a good blog article of an MVP called Luise Freese. You can find the complete article [here](https://regarding365.com/putting-some-more-fun-into-azure-functions-managed-identity-microsoft-graph-f9a51319f4e5){:target="_blank"}

You essentially will need the following Az CLI commands for doing a Microsoft Graph delegated permission
(Sample with the Group.Read.All permission):

If you do not know the Microsoft Graph permissions you can find the complete permission reference [here](https://docs.microsoft.com/en-us/graph/permissions-reference){:target="_blank"}

```bash
#Save that service provider
$graphId = az ad sp list --query "[?appDisplayName=='Microsoft Graph'].appId | [0]" --all

# Get permission scope for "Group.Read.All"
$appRoleId = az ad sp show --id $graphId --query "appRoles[?value=='Group.Read.All'].id | [0]"

#Set values
$webAppName="<your function app name>"

$principalId=$(az resource list -n $webAppName --query [*].identity.principalId --out tsv)

$graphResourceId=$(az ad sp list --display-name "Microsoft Graph" --query [0].objectId --out tsv)

$appRoleId=$(az ad sp list --display-name "Microsoft Graph" --query "[0].appRoles[?value=='Group.Read.All' && contains(allowedMemberTypes, 'Application')].id" --out tsv)

$body="{'principalId':'$principalId','resourceId':'$graphResourceId','appRoleId':'$appRoleId'}"

#the actual REST call
az rest --method post --uri https://graph.microsoft.com/v1.0/servicePrincipals/$principalId/appRoleAssignments --body $body --headers Content-Type=application/json
```

That's it for this post. Thank you for reading.