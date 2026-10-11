---
layout: post
title: "Dev Containers for PowerShell, Part 1: Set Up Once, Use Anywhere"
date: 2026-10-11
tags: [PowerShell, "VS Code", "Dev Containers", "GitHub Codespaces"]
---

"It works on my machine." Every team has heard that sentence. One colleague has Pester 4, the other has Pester 5. One formats with OTBS, the other with Allman. One has the Az module from last year. The code review is full of whitespace changes, and the test that is green for me is red in the pipeline.

Dev containers fix this. The whole development environment, consisting of the PowerShell version, modules, VS Code extensions and settings is in one file in the repository. Everybody who opens the repository gets the same environment. On a work laptop, on a private PC, or in the browser with GitHub Codespaces.

The source code for this post is in my [BlogAssets](https://github.com/constantinhager/BlogAssets/tree/main/Dev%20Containers%20Part%201%20Setup%20Once%20Use%20Anywhere){:target="_blank"} repository.

This is a two-part series:

- **Part 1 (this post):** Dev containers with VS Code. Create a `devcontainer.json` with the extension, build a PowerShell environment on Microsoft's .NET dev container image, and use it in GitHub Codespaces.
- **Part 2:** Build your own container image and host it in your own container registry.

## What is a dev container?

A dev container is a Docker container that VS Code uses as a full development environment. Your files stay in the repository. VS Code runs its UI on your machine, but the terminal, the extensions and PowerShell run **inside** the container.

The configuration lives in `.devcontainer/devcontainer.json`. The format is an open specification ([containers.dev](https://containers.dev/)). VS Code, GitHub Codespaces and the Dev Container CLI all read the same file.

A `devcontainer.json` describes among other things:

| Part                      | What it does                                             |
| ------------------------- | -------------------------------------------------------- |
| `image` (or a Dockerfile) | The base image: operating system plus preinstalled tools |
| `features`                | Tools you add on top, e.g. Azure CLI, GitHub CLI         |
| `customizations.vscode`   | The VS Code extensions and settings inside the container |

## What you need

- [Visual Studio Code](https://code.visualstudio.com/){:target="_blank"}
- The [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers){:target="_blank"} (`ms-vscode-remote.remote-containers`)
- A container runtime: Docker Desktop, or Docker Engine in WSL 2 on Windows. Podman also works.

For GitHub Codespaces you need nothing local. A browser is enough.

## Create the devcontainer.json with the extension

You don't have to write the file by hand. The Dev Containers extension has a wizard for it.

1. Open your project folder in VS Code.
2. Open the command palette with `Ctrl+Shift+P` (`Cmd+Shift+P` on macOS) and run **Dev Containers: Add Dev Container Configuration Files...**
3. Choose where the configuration goes. **Add configuration to workspace** writes it into the repository. That's what you want for a team.
4. Pick a template. The list is sorted by the content of your folder. There is an old PowerShell template. Type `.NET` and select **C# (.NET)** (from the official `devcontainers` templates). Don't see it? Use **Show All Definitions...**.
5. Pick the .NET version. `10.0-noble` is the default. Keep it.
6. Type `Azure CLI` in the search box and tick **Azure CLI**. Add **GitHub CLI** the same way. Confirm with **OK**.
7. VS Code asks about the feature options. **Keep Defaults** is fine here.
8. VS Code creates `.devcontainer/devcontainer.json` and offers to reopen the folder in the container.

It works. But it is only a starting point. The commented-out blocks are exactly the parts that make the environment useful for a team: the modules, the post-create script and the VS Code settings. The next sections fill them in.

Want to add or remove a feature later? Run **Dev Containers: Configure Container Features**. It opens the same feature picker and updates the existing file.

## Why the .NET image?

Microsoft publishes a [.NET dev container image](https://github.com/devcontainers/images/tree/main/src/dotnet): `mcr.microsoft.com/devcontainers/dotnet`. It is built on the official .NET SDK image (`mcr.microsoft.com/dotnet/sdk`). And the .NET SDK image ships **PowerShell** - installed as a .NET global tool, with `pwsh` linked to `/usr/bin/pwsh`.

So `pwsh` is there from the first second. No feature, no install script, no extra build time. PSResourceGet comes with it, so `Install-PSResource` works right away. On top, the dev container image adds Git, a non-root `vscode` user and the usual tools.

Two things to know:

> **The image decides the PowerShell version.** It is the version that the .NET team bundles into the SDK image. When I wrote this, the .NET 10 SDK image for Ubuntu 24.04 contained PowerShell 7.6.6. A newer image tag brings a newer PowerShell. Check it with `$PSVersionTable` after the build.
{: .prompt-info}

> **The image is bigger.** It contains the full .NET SDK. For PowerShell work alone, that's more than you need. If you want a smaller image or a specific PowerShell version, take `mcr.microsoft.com/devcontainers/base:noble` and add the [PowerShell feature](https://github.com/devcontainers/features/tree/main/src/powershell) (`ghcr.io/devcontainers/features/powershell:2`) instead. Its `version` option accepts e.g. `lts`, `stable`, `preview` or `7.5`.
{: .prompt-warning}

## The folder structure

```
my-powershell-project/
├── .devcontainer/
│   ├── devcontainer.json   # the environment
│   └── postCreate.ps1      # runs once after the container is created
├── your source code/
```

My [devcontainer.json](https://github.com/constantinhager/BlogAssets/blob/main/Dev%20Containers%20Part%201%20Setup%20Once%20Use%20Anywhere/.devcontainer/devcontainer.json){:target="_blank"} and [postCreate.ps1](https://github.com/constantinhager/BlogAssets/blob/main/Dev%20Containers%20Part%201%20Setup%20Once%20Use%20Anywhere/.devcontainer/postCreate.ps1){:target="_blank"}.

What happens here:

- **`image`**: The container is based on `mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble` (.NET 10 on Ubuntu 24.04). The tag is pinned and PowerShell comes with the image.
- **`features`**: Azure CLI and GitHub CLI are added on top, both pinned to major version `1`.
- **`containerEnv`**: Turns off PowerShell telemetry (`POWERSHELL_TELEMETRY_OPTOUT`) and the update check (`POWERSHELL_UPDATECHECK`).
- **`postCreateCommand`**: Runs `.devcontainer/postCreate.ps1` with `pwsh` once after the container is created. This is the place to install modules like Pester.
- **`customizations.vscode.extensions`**: Installs the PowerShell extension, Pester Test, Error Lens, inline values for PowerShell, PowerShell Pro Tools, Region Viewer, vscode-icons, EditorConfig and GitLens.
- **`customizations.vscode.settings`**: Shared editor settings for the whole team. This includes format on save, type and paste, bracket pair guides, Git helpers, terminal options and PowerShell as the default language. There are also launch configurations (`PS: Interactive`, `PS: Run`, `PS: Run w/ Args`, `PS: Pester`) and PowerShell formatting rules (OTBS preset, correct casing, aliases are expanded).
- **`remoteUser`**: Everything runs as the non-root user `vscode`.

The `postCreate.ps1` script does the following:

- **`#Requires -Version 7.4`**: The script stops if the PowerShell version is older than 7.4. This is the first version that ships PSResourceGet.
- **`$ErrorActionPreference = 'Stop'`**: Any error stops the script, so a failed module install fails the container creation. You see the problem right away.
- **`$modules`**: The list of modules every team member needs: Pester, PSScriptAnalyzer, PSFramework and EntraAuth. This is the place to pin versions (see [Tips from practice](#tips-from-practice)).
- **`Get-PSResourceRepository` and `Set-PSResourceRepository`**: On a fresh container the repository store doesn't exist yet. The first `Get-PSResourceRepository` call creates it. Then PSGallery is marked as trusted, so there are no prompts.
- **`Install-PSResource`**: Installs each module for the current user (`-Scope CurrentUser`) without prompts (`-TrustRepository`, `-Quiet`).
- **`Get-InstalledPSResource`**: Prints a table of the installed modules and versions at the end. You can check the result in the creation log.

## Open the project in the container

1. Open the repository folder in VS Code.
2. If the Dev Containers extension is installed, VS Code finds `.devcontainer/devcontainer.json` and asks: **Reopen in Container**. Or open the command palette with `Ctrl+Shift+P` (`Cmd+Shift+P` on macOS) and run **Dev Containers: Reopen in Container**.
3. The first start builds the container. That takes a few minutes. Later starts take seconds.
4. The bottom-left corner shows **Dev Container: PowerShell**. The terminal is `pwsh`, the modules are there.

Check it in the terminal:

```powershell
pwsh
$PSVersionTable.PSVersion
Get-Module -ListAvailable | Select-Object Name, Version
```

Did you change `devcontainer.json`? Run **Dev Containers: Rebuild Container**. The container is thrown away and built again from the file. That's the point: the file is the truth, not the state of the container.

## The same environment in the browser: GitHub Codespaces

GitHub Codespaces reads the same `devcontainer.json`. No extra file. In the repository on GitHub:

1. **Code** -> **Codespaces** -> **Create codespace on main**.
2. GitHub builds the container in the cloud and opens VS Code in the browser.

That is the "use anywhere" part. I can fix a script from a tablet or a borrowed PC, with my extensions, my settings and my modules. Nothing is installed locally.

> Codespaces costs compute time and storage. Personal accounts get a monthly free quota. Check your [billing settings](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-codespaces/about-billing-for-github-codespaces){:target="_blank"} and set an idle timeout.
{: .prompt-info}

## Tips from practice

- **Pin versions.** `dotnet:2-10.0-noble` instead of `latest`. `azure-cli:1` instead of no tag. `Pester` `5.9.1` instead of "whatever is newest". A dev container that builds differently next month is the same problem as before, just slower. In `postCreate.ps1` add a `Version` to every module entry. `Install-PSResource` accepts an exact version:

  ```powershell
  $modules = @(
      @{ Name = 'Pester'; Version = '5.9.1' }
      @{ Name = 'PSScriptAnalyzer'; Version = '1.25.0' }
      @{ Name = 'PSFramework'; Version = '1.14.457' }
  )
  ```
- **Credentials don't belong in the image.** Sign in inside the container with `az login --use-device-code`. The Dev Containers extension forwards your local Git credentials automatically.
- **Same file for CI.** The [Dev Container CLI](https://github.com/devcontainers/cli) (`devcontainer up`, `devcontainer exec`) runs the same container in a pipeline. Then the tests in CI run in exactly the environment you developed in.

## My PSConfEU talks about dev containers

I presented dev containers twice at the [PowerShell Conference Europe](https://psconf.eu/):

**Create a Development Environment for PowerShell Universal** - PSConfEU 2024, Antwerp
[![Create a Development Environment for PowerShell Universal](https://img.youtube.com/vi/EVXqi312BH8/hqdefault.jpg){: width="640" }](https://www.youtube.com/watch?v=EVXqi312BH8){:target="_blank" rel="noopener noreferrer"}

PowerShell Universal is great for dashboards, scheduled scripts and REST APIs. But every developer needs the same PSU version, the same modules and the same configuration. In this talk I showed what dev containers are, how to build one for PowerShell Universal, and how to set up VS Code to work with it. The goal: no more "it works on my machine" in a PSU team.

**VSCode everywhere: Set Up Once, Use Anywhere** - PSConfEU 2026, Wiesbaden
[![VSCode everywhere: Set Up Once, Use Anywhere](https://img.youtube.com/vi/jsp1mZVhDzQ/hqdefault.jpg){: width="640" }](https://www.youtube.com/watch?v=jsp1mZVhDzQ){:target="_blank" rel="noopener noreferrer"}

This talk went one step further. Different editor settings across devices and team members create more than formatting differences. They add noise to code reviews and make consistent code harder. I showed how to build a shared, portable VS Code setup for PowerShell with dev containers - one that works on a work laptop, a private PC or a tablet - and how to run it in the browser with GitHub Codespaces.

## Conclusion

A dev container turns "install these ten things and configure VS Code like this" into one file in the repository. New team members are productive after one click. The code review is about code again, not about whitespace. And with GitHub Codespaces the same environment runs in the browser.

Start small: let the extension create the file, or copy my [devcontainer.json](https://github.com/constantinhager/BlogAssets/blob/main/Dev%20Containers%20Part%201%20Setup%20Once%20Use%20Anywhere/.devcontainer/devcontainer.json){:target="_blank"} and [postCreate.ps1](https://github.com/constantinhager/BlogAssets/blob/main/Dev%20Containers%20Part%201%20Setup%20Once%20Use%20Anywhere/.devcontainer/postCreate.ps1){:target="_blank"} into a project. Open it in the container and add what your team needs.

## Coming up in Part 2

In this post, every container starts from Microsoft's .NET dev container image. The features and the post-create script install the tools and modules on top. That works, but it happens on every build. And the result depends on what the Gallery and the feature scripts deliver on that day.

In Part 2 I build my own container image. PowerShell, the modules and the tools are baked in. I push the image to my own container registry. The `devcontainer.json` then only points to that image. Every team member and every codespace starts from exactly the same, tested image.
