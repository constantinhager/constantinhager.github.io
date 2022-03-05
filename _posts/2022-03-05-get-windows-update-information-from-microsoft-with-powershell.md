---
title: Get Windows Update Information from Microsoft with PowerShell
date: 2022-03-05 18:20 +0100
categories: [PowerShell]
tags: [PowerShell, Windows Update]
---

Today I had the challenge to find information for a specific Windows Update.

I only know the KB number of that particular Windows Update but I want to get the following information:

- Name of the Windows Update
- The update information URL from Microsoft

So I wrote a PowerShell function for this.

```powershell
function Get-CHWindowsUpdateInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateLength(1,9)]
        [string]
        $KB
    )

    # Build the search URL and get the results of
    # that query back.
    $SearchURL = [string]::Concat('https://support.microsoft.com/en-us/Search/results?query=', $KB)
    $result = Invoke-WebRequest -Uri $SearchURL

    # Searching for the Windows Update Link for that
    # specific KB.
    $URL = $result.Links |
    Where-Object { $_.outerHTML.Contains($KB) } |
    Select-Object -First 1 |
    Select-Object -ExpandProperty href

    # Searching for the Windows Update Name for that
    # specific KB.
    $Title = $result.Links |
    Where-Object { $_.outerHTML.Contains($KB) } |
    Select-Object -First 1 |
    Select-Object -ExpandProperty title

    # If both values are empty I will return $null
    # else I return the update information as a
    # PSCustomObject.
    if([string]::IsNullOrEmpty($URL) -and [string]::IsNullOrEmpty($URL)) {
        return $null
    } else {
        return [PSCustomObject]@{
            WindowsUpdateTitle = $Title
            WindowsUpdateURL   = $URL
        }
    }
}

```