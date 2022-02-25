---
title: 'Add Custom ArgumentCompleters to your CMD-Lets'
date: '2016-12-03T19:01:43+01:00'
categories: [PowerShell]
tags: [PowerShell]
---

If we take a PowerShell CMD-Let like Get-AdComputer and try to search for a specific computer, you have to specify the filter- or the identity property and you have to remember the name. If you have a domain / more domains with hundreds of PCs you don’t know them all. So would It be good to add intellisense for that?

So let’s do that.

You have to install an extension called TabExpansionPlusPlus.

You can download that module at GitHub at the following URL: [Link TabExpansion++](https://github.com/lzybkr/TabExpansionPlusPlus/tree/DropScanningRegistration). Download that repository and copy It to your modules script folder.

If we look at all the commands we see this result:

![getcommandtabexpansion](/assets/pictures/2016-12-03/GetCommandTabExpansion.png)

For this tutorial we need the following CMD-Lets:

- Register-ArgumentCompleter
- New-CompletionResult

The main CMD-Let that we use is the Register-ArgumentCompleter. For this comannd we need the following parameters:

- CommandName: The name of the PowerShell Command for that we want to register the argumentcompleter.
- ParameterName: The specified parameter from that PowerShell CMD-Let where we want to have argumentcompletion.
- ScriptBlock: The Script that runs everytime the intellisense got invoked. The returnvalue has to be a CompletionResult.

So let’s look at some code for that.

```powershell
$ScriptBlock = {
  # Parameters:
  # CommandName : The name of the PowerShell command that the auto-completer applies to.
  # ParameterName : The name of the PowerShell command parameter that will be auto-completed.
  # WordToComplete : The partial text that will be auto-completed.
  param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

  # Get all OUs and match the result with the input
  $allous = ActiveDirectory\Get-ADOrganizationalUnit -Filter * | Where-Object -FilterScript {$PSItem.Name -match $wordToComplete}

  # Loop through each result and generate a new CompletionResult
  foreach ($ou in $allous)
  {
    # CompletionText: The text that the command needs
    # Tooltip: That infobox when you select one result in the intellisense
    # ListItemText: The text that will be shown in the intellisense-listbox for better readability
    # CompletionResultType: The Type of the result
    New-CompletionResult -CompletionText $ou.DistinguishedName -ToolTip 'The OU Name' -ListItemText $ou.Name -CompletionResultType ParameterValue
  }
}

# Register a custom intellisense for the Command Get-AdComputer for the parametername Searchbase and invoke the scriptblock
Register-ArgumentCompleter -CommandName 'Get-AdComputer' -ParameterName SearchBase -ScriptBlock $ScriptBlock
```

That’s It. All you have to do is to run that code and you have registered your first argumentcompleter. If you now type Get-AdComputer -SearchBase you will now get intellisense for it.

![get-adcomputer-intellisense](/assets/pictures/2016-12-03/Get-AdComputer-Intellisense.png)

So if you don’t want to lose the argumentcompleter, you have to save It in the tabexpansion++-module directory. The name has to be in the following format:

**Microsoft.PowerShell.Core.\[YourChoice\].ArgumentCompleters.ps1**

The **ArgumentCompleters** part in the filename is very important, because if this module loads It will look for all files with that word at the end of the filename.

So if you want to show your argumentcompleters to show up import the module TabExpansion++. For instance you can do that in your PowerShell profile.