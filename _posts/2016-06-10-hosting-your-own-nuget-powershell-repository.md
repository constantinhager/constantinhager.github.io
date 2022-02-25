---
title: 'Hosting Your Own NuGet PowerShell Repository'
date: '2016-06-10T14:55:55+01:00'
categories: [PowerShell]
tags: [PowerShell]
---

Today I want to show you how to host your own NuGet Repository for uploading PowerShell Modules / Scripts.

There is also a method for hosting a NuGet Fileshare, but for production environments it is better to set up a Web Server and host a NuGet Repository.

In this demonstration I use Windows Server 2012 R2 (Nuget) and have another machine (Windows 10 (DEV)) with Visual Studio Community installed.

On the Server Side (Nuget) we need to do the following things:

- Install WMF5 (Windows Management Framework 5 (PowerShell 5))
- Install PackageManagement

You can get this two things from the following site: [PowerShell Gallery](https://www.powershellgallery.com/)

If you have Windows Server 2016 or Windows 10 you don’t need to do this because they are already installed.

Furthermore we need to install IIS and IIS Rewrite Tool and [.Net Framework 4.5.2](https://www.microsoft.com/en-US/download/details.aspx?id=42642).

First Install IIS with the following PowerShell command:

```powershell
Install-WindowsFeature NET-Framework-Core,NET-Framework-45-ASPNET,Web-Default-Doc,Web-Static-Content,Web-Http-Logging,Web-Stat-Compression,Web-Filtering,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Console,Net-Framework-Core -Source D:\sources\sxs
```

After that install the IIS Rewrite Tool from the following site: [Download IIS Rewrite Tool](http://go.microsoft.com/?linkid=9722532)

Before we Build the NuGet Server you have to install the Windows Azure SDK. You can get it via the [Microsoft Web Plattform Installer](https://www.microsoft.com/web/downloads/platform.aspx). Install It and search for Windows Azure SDK. In my case i have to install the SDK for Visual Studio 2015.

You also need to install a SQL Server (Express/Std./Enterprise.). I will use SQL Express 2014.

After you installed SQL-Server, we need to create a SQL-login for the Entity Framework to create the database.
The SQL-Login needs to have db_creator rights.
I will name mine nuget_user.

Right Click on the server and select Properties -&gt; Security -&gt; SQL Server and Windows Authentication mode.
I also disable the firewall on the server. You have to restart SQL Server.

To publish a NuGet Server to IIS i use an extra client with visual Studio on it. In this example we use the Nuget Gallery. You can get it from there: [Download NuGet Gallery](https://github.com/NuGet/NuGetGallery).

Download the Zip File and unblock and extract it and open the .sln-File.
If you get any Warnings that you need to install SQL Express Local DB click OK.

Search for the project NuGetGallery and right-click on References -&gt; Manage NuGet-Packages. Then click Restore.

On the menu click Build -&gt; Build Application. The application should build without any errors.

Go to NuGetGallery -&gt; web.config and change (in my case) the following entries:

In web.config go to line 129 and change the connection string like:

```xml
<connectionStrings>
  <add name="NuGetGallery" connectionString="Server=MyMachineName\MYSQLSERVERNAME;Initial Catalog=NuGetGallery;User ID=nuget_user;Password=MyNuGetStrongPwd1;" providerName="System.Data.SqlClient" />
</connectionStrings>
```

Line 107 change "Gallery.ConfirmEmailAddresses" value="true" to
"Gallery.ConfirmEmailAddresses" value="false".

Now we need to create the database for the NuGet Gallery. In Visual Studio open the NuGet Package Manager Console (Tools -&gt; NuGet Package Manager -&gt; Package Manager Console).

Type in the following command:

```powershell
Update-Database -ConfigurationTypeName MigrationsConfiguration
```

After the database is deployed we can remove the user right "dbcreator" for the nuget_user. Furthermore we select the default database to be NuGetGallery. And in the "User Mapping" dialog I select db_owner but best pratice would be the roles "db_datareader and db_datawriter".

After that you should see a new database in the management studio called NuGetGallery.

After that we need to create a new website (in my case i stopped the default web site).
We then need to create a new Application Pool and assign it to the website.
For that i have the following PowerShell script:

```powershell
# Stop Default Web Site
Stop-Website -Name 'Default Web Site'

# Remove the Website
Remove-Website -Name 'Default Web Site'

# Create a new Application Pool
New-WebAppPool -Name 'NuGetGallery'

# Create the folder for the site
New-Item -ItemType Directory -Path 'C:\inetpub\wwwroot\NuGet'

# Create new WebSite
New-Website -Name 'NuGetGallery' -PhysicalPath 'C:\inetpub\wwwroot\NuGet' -ApplicationPool 'NuGetGallery'
```

Next we need to assign the right permissions to the folders. Therefore I created another PowerShell script:

```powershell
# User that need to be added
$user_iusr = 'IUSR'
$user_apppool = 'IIS APPPOOL\NuGetGallery'

# Get ACL from C:\inetpub\wwwroot\NuGet
$acl = Get-Acl -Path 'C:\inetpub\wwwroot\NuGet'

# Define Accessrule for AppPool identity
$ar_apppool = New-Object System.Security.AccessControl.FileSystemAccessRule($user_apppool,'Modify','ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.SetAccessRule($ar_apppool)
Set-Acl -Path 'C:\inetpub\wwwroot\NuGet' -AclObject $acl

# Define Accessrule for IUSR
$ar_IUSR = New-Object System.Security.AccessControl.FileSystemAccessRule($user_iusr,'Modify','ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.SetAccessRule($ar_IUSR)
Set-Acl -Path 'C:\inetpub\wwwroot\NuGet' -AclObject $acl
```

Next we need to publish the NuGetGallery to our IIS Server.
To do that right-click the solution NuGetGallery in Visual Studio an click publish.
Click on custom. Type in a name. Change the publish method to "File System" and type the UNC-Path to the sitepath and publish it.

If you open a Web Browser and Type http://[Your Server Name]. You should see a working NuGet Gallery.

Next you have to register for an account. Click in the upper right corner Register / Sign In.

Now we have to install the PackageProvider Nuget. With the following coomand you install the NuGet Provider.

```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
```

After that you can register the PowerShell repository with the following command:

```powershell
Register-PSRepository -Name NugetRepo -SourceLocation 'http://[SERVERNAME]/api/v2' -PublishLocation 'http://[SERVERNAME]/' -InstallationPolicy Trusted
```

To upload a PowerShell Module type the following PowerShell command:

```powershell
Publish-Module -Repository NugetRepo -NuGetApiKey [YOUR API KEY] -Name [YOUR MODULE NAME] [-Verbose]
```

To upload another version of the same script edit the .psd1 and change the version. Then upload again.

If you want to find a module in a specified repository the following command will help:

```powershell
Find-Module -Repository [YOUR NUGET REPO] -Name [YOUR MODULE NAME] [-AllVersions]
```

If you want to install a Module from a Repository type in the following code:

```powershell
Install-Module -Repository [YOUR NUGET REPO] -Name [YOUR MODULE NAME]
```

If you want to upload a script to the NuGetGallery you have to perform the following steps:

- You have to create a file with a specified template to upload it to the gallery. You can do that with the following command (The file shouldn’t exist, otherwise you will get an error):

```powershell
New-ScriptFileInfo -Path [YOUR PATH].ps1 -Description [YOUR DESCRIPTION]
```

- Paste the code from your script into the file that you have created earlier (Leave at least one line empty between the comments and the actual code).
- Test the ScriptFileInfo with the following command:

```powershell
Test-ScriptFileInfo -Path [YOUR PATH]
```

If there is no error than you can upload it to the gallery with the following command:

```powershell
Publish-Script -Path [YOUR SCRIPT PATH] -Repository [YOUR NUGET REPO] -NuGetApiKey [YOUR NUGET API KEY] -Verbose
```

If you open the gallery now you should see 2 entries. One Module and one Script.

That’s it for this tutorial.