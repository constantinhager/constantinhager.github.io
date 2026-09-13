---
layout: post
title: PSAzureSQLElasticJob - A PowerShell module for Azure SQL Elastic Jobs
date: 2026-08-21 14:03 +0200
categories: [PowerShell, Azure SQL]
tags: [PowerShell, Azure SQL, Azure]
---

Azure SQL Elastic Jobs let you run a T-SQL script across many Azure SQL databases on a schedule or on demand - think
nightly maintenance, cross-database reporting, or rolling out a schema change to a fleet of tenant databases.
The underlying `Az.Sql` cmdlets work, but they're low-level: you get raw create/update/delete operations with no
idempotency, no `$null`-on-missing semantics, and no tab completion.

I built **PSAzureSQLElasticJob** to close that gap. It's a PowerShell module that wraps the Elastic Jobs cmdlets
in `Az.Sql` with the conventions I want from any infrastructure module I maintain.

## Features that I add

- **Idempotent `New-*` commands.** Run them twice and the second call just returns the existing resource
instead of throwing.

- **Non-throwing `Get-*` commands.** They return `$null` when a resource doesn't exist, so you can use them directly
in `if` checks instead of wrapping every call in try/catch.

- **Consistent `-Strict`/`-PassThru` semantics** on every `Remove-*` command.

- **`-WhatIf`/`-Confirm` support** throughout.

- **Microsoft Entra (Azure AD) user-assigned managed identities** as the recommended way to authenticate job steps
against target databases no stored SQL credential needed.

- **Tab completion** for resource group, server, database, agent, job, step, credential and target group names,
scoped by whatever earlier parameters are already typed. Completing `-Name` on `Get-SqlElasticJobStep` only suggests
steps that exist on the `-JobName` you already typed.

## How to use PSAzureSQLElasticJob

```powershell
Connect-AzAccount

# 1. Provision the logical SQL server, job database, Elastic Job agent and a
#    user-assigned managed identity in one idempotent call.
$credential = Get-Credential -UserName 'sqladmin'

$Parameters = @{
    ResourceGroupName                 = 'rg-jobs'
    ServerName                        = 'sql-jobs'
    DatabaseName                      = 'jobdb'
    AgentName                         = 'agent01'
    Location                          = 'westeurope'
    ServerAdministratorCredential     = $credential
    CreateUserAssignedManagedIdentity = $true
    UserAssignedIdentityName          = 'id-jobs'
}
New-SqlElasticJobEnvironment @Parameters

# 2. Define what the job runs against.
$Parameters = @{
    ResourceGroupName = 'rg-jobs'
    ServerName        = 'sql-jobs'
    AgentName         = 'agent01'
    Name              = 'targetgroup01'
}
New-SqlElasticJobTargetGroup @Parameters |
Add-SqlElasticJobTarget -TargetServerName 'sql-app' -TargetDatabaseName 'AppDb'

# 3. Grant the managed identity a database user + role on the target so job
#    steps can authenticate without a stored credential.
$Parameters = @{
    TargetServerName   = 'sql-app'
    TargetDatabaseName = 'AppDb'
    IdentityName       = 'id-jobs'
}
Grant-SqlElasticJobTargetDatabaseAccess @Parameters

# 4. Create the job and its steps.
$Parameters = @{
    ResourceGroupName = 'rg-jobs'
    ServerName        = 'sql-jobs'
    AgentName         = 'agent01'
    Name              = 'nightly-report'
    RunOnce           = $true
}
New-SqlElasticJob @Parameters

$Parameters = @{
    ResourceGroupName = 'rg-jobs'
    ServerName        = 'sql-jobs'
    AgentName         = 'agent01'
    JobName           = 'nightly-report'
    Name              = 'collect-counts'
    TargetGroupName   = 'targetgroup01'
    CommandText       = 'SELECT COUNT(*) AS RowCount FROM dbo.Orders'
}
Add-SqlElasticJobStep @Parameters

# 5. Run it and wait for the result.
$Parameters = @{
    ResourceGroupName = 'rg-jobs'
    ServerName        = 'sql-jobs'
    AgentName         = 'agent01'
    Name              = 'nightly-report'
    Wait              = $true
}
$execution = Start-SqlElasticJob @Parameters
```

That's provisioning, target setup, permissions, job creation and execution - end to end, without touching the Azure Portal.

One detail worth calling out: if a step writes results to an output table, it has to select `$(job_execution_id)` explicitly in its `CommandText`. Azure's own system-managed output column can't be correlated back to a specific run, so `Get-SqlElasticJobExecutionOutput` relies on that explicit column to filter rows for one execution.

Version 1.0.1 is out now, with the full command reference in the README.

## Get it

```powershell
Install-Module -Name PSAzureSQLElasticJob -Scope CurrentUser

Install-PSResource -Name PSAzureSQLElasticJob -Repository PSGallery -Scope CurrentUser
```

Source, full command reference and the changelog are on GitHub: [PSAzureSQLElasticJob](https://github.com/constantinhager/PSAzureSQLElasticJob).

Issues and PRs are welcome — it's MIT licensed.
