---
title: 'Delegate access in Active Directory with PowerShell'
date: '2019-08-06T18:03:16+01:00'
categories: [PowerShell]
tags: [PowerShell, Active Directory]
---

In this blog post I’m going to show you how to delegate Active Directory permissions to other Active Directory groups.

Prerequisite for that is the PowerShell Module ActiveDirectory.
You can get that through the RSAT package.

There are some cases where this makes sense:

- delegate rights to all user objects in a specific OU
- delegate rights to reset the password
- and so on.

To do that we need to change the ACL (Access Control List) on an Organizational Unit (OU). Luckily there is already a Cmdlet for that.
It Is called:

```powershell
Get-Acl
```

In order to retrieve the ACL from a specific OU you have to use the Active Directory PSDrive (AD:\\) for that. A quick example is:

```powershell
$acl = Get-Acl -Path "AD:\OU=SomeOU,dc=contoso,dc=com"
```

In this step we get the complete ACL. Now we want to add one Access Rule. Before we can add the access rule we have to prepare some things to make our live easier.

In Active Directory every permission and property has a specific GUID that we need later. To get all GUIDs and their names, we use the following functions.

```powershell
function New-ADDGuidMap
{
    <#
    .SYNOPSIS
        Creates a guid map for the delegation part
    .DESCRIPTION
        Creates a guid map for the delegation part
    .EXAMPLE
        PS C:\> New-ADDGuidMap
    .OUTPUTS
        Hashtable
    .NOTES
        Author: Constantin Hager
        Date: 06.08.2019
    #>
    $rootdse = Get-ADRootDSE
    $guidmap = @{ }
    $GuidMapParams = @{
        SearchBase = ($rootdse.SchemaNamingContext)
        LDAPFilter = "(schemaidguid=*)"
        Properties = ("lDAPDisplayName", "schemaIDGUID")
    }
    Get-ADObject @GuidMapParams | ForEach-Object { $guidmap[$_.lDAPDisplayName] = [System.GUID]$_.schemaIDGUID }
    return $guidmap
}

function New-ADDExtendedRightMap
{
    .SYNOPSIS
        Creates a extended rights map for the delegation part
    .DESCRIPTION
        Creates a extended rights map for the delegation part
    .EXAMPLE
        PS C:\> New-ADDExtendedRightsMap
    .NOTES
        Author: Constantin Hager
        Date: 06.08.2019
    #>
    $rootdse = Get-ADRootDSE
    $ExtendedMapParams = @{
        SearchBase = ($rootdse.ConfigurationNamingContext)
        LDAPFilter = "(&(objectclass=controlAccessRight)(rightsguid=*))"
        Properties = ("displayName", "rightsGuid")
    }
    $extendedrightsmap = @{ }
    Get-ADObject @ExtendedMapParams | ForEach-Object { $extendedrightsmap[$_.displayName] = [System.GUID]$_.rightsGuid }
    return $extendedrightsmap
}
```

Now that we have all normal rights like "user" or "group" we now have exteded rights like "reset password" also.

To use these Associative arrays we need to call the functions and store the return values
in variables. We use them throughout the blog.

```powershell
$GuidMap = New-ADDGuidMap
$ExtendedRight = New-ADDExtendedRightMap
```

The next step is that we need the SID of the target AD object.

```powershell
$Group = "Blog"
$GroupSID = New-Object System.Security.Principal.SecurityIdentifier (Get-ADGroup $Group).SID
```

After that we need the DistinguishedName of the OU where our Group will get delegated. In our example It is BlogOU.

```powershell
$dn = Get-ADOrganizationalUnit -Filter "Name -eq 'BlogOU'" | Select-Object -ExpandProperty DistinguishedName
```

Before we can start we need the ACL of the OU. We get that with the following code:

```powershell
$acl = Get-Acl -Path "AD:\$dn"
```

Now that we have all information to delegate the appropiate permissions to the Blog group we get to the tricky part.

We have to use .Net functionality to add an ActiveDirectoryAccess Rule. You will find the complete documentation in the docs [here](https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectoryaccessrule?view=netframework-4.8).

The code that we will use to create an ActiveDirectoryAccessRule is the following:

```powershell
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $GroupSID, "GenericAll", "Allow", "Descendents", $GuidMap["user"]
```

The explanation of all Parameters:

- $GroupSID: System.Security.AccessControl.IdentityReference
- GenericAll: [System.DirectoryServices.ActiveDirectoryRights](https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectoryrights?view=netframework-4.8)
- Allow: [System.Security.AccessControl.AccessControlType](https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.accesscontroltype?view=netframework-4.8)
- Descendents: [System.DirectoryServices.ActiveDirectorySecurityInheritance](https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectorysecurityinheritance?view=netframework-4.8)
- $GuidMap["user"]: The Schema GUID for user object in Active Directory

We specified in this line that the Blog group gets Full control (GenericAll) to all descendant User objects in the BlogOU.

Now we need to add the ActiveDirectoryAccessRule to our ACL object.

```powershell
$acl.AddAccessRule($ace)
```

The final step is to write back the changed ACL object to the BlogOU.

```powershell
Set-ACL -Path "AD:\$dn" -AclObject $acl
```

To check if everything worked correctly use this code:

```powershell
$acl = Get-Acl -Path "AD:\$dn"
$acl.Access.Where({$_.IdentityReference -eq "<yourDomain>\$Group"})
```

The result should be something like this.

```powershell
ActiveDirectoryRights : GenericAll
InheritanceType       : Descendents
ObjectType            : 00000000-0000-0000-0000-000000000000
InheritedObjectType   : bf967aba-0de6-11d0-a285-00aa003049e2
ObjectFlags           : InheritedObjectAceTypePresent
AccessControlType     : Allow
IdentityReference     : <your domain>\Blog
IsInherited           : False
InheritanceFlags      : ContainerInherit
PropagationFlags      : InheritOnly
```

Why I know that this is the appropriate entry? You should have an eye on the InheritedObjectType.

```powershell
$GuidMap["user"]

Guid
----
bf967aba-0de6-11d0-a285-00aa003049e2
```

If we return the GUID for user in the hashtable $GuidMap It maps with InheritedObjectType.

If we want to delegate reset passwords right for the Group we use the extended right guid map for this.

>Note: If you do this on the BlogOU where the Blog group has full control the extended right for resetting the password will not be shown because the group already has the rights. If you want to try this with the Blog group delete the Full control rights first.
{: .prompt-info}

The code for the extended right ActiveDirectoryAccessrule is:

```powershell
$acl = Get-Acl -Path "AD:\$dn"
$Acee = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $GroupSID, "ExtendedRight", "Allow", $ExtendedRight["reset password"] , "Descendents", $GuidMap["user"]
$acl.AddAccessRule($Acee)
Set-Acl -Path "AD:\$dn" -AclObject $acl

```

- $GroupSID: System.Security.AccessControl.IdentityReference
- ExtendedRight: [System.DirectoryServices.ActiveDirectoryRights](https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectoryrights?view=netframework-4.8)
- Allow: [System.Security.AccessControl.AccessRule](https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.accesscontroltype?view=netframework-4.8)
- $ExtendedRight["reset password"]: The schema GUID for the "reset password" extended rights object in Active Directory
- Descendents: [System.DirectoryServices.ActiveDirectorySecurityInheritance](https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectorysecurityinheritance?view=netframework-4.8)
- $GuidMap["user"]: The schema GUID for user object in Active Directory

 To check if everything worked correctly use this code:

```powershell
$acl = Get-Acl -Path "AD:\$dn"
$acl.Access.Where({$_.IdentityReference -eq "<yourDomain>\$Group"})
```

The result should be something like this.

```powershell
ActiveDirectoryRights : ExtendedRight
InheritanceType       : Descendents
ObjectType            : 00299570-246d-11d0-a768-00aa006e0529
InheritedObjectType   : bf967aba-0de6-11d0-a285-00aa003049e2
ObjectFlags           : ObjectAceTypePresent, InheritedObjectAceTypePresent
AccessControlType     : Allow
IdentityReference     : <your domain>\Blog
IsInherited           : False
InheritanceFlags      : ContainerInherit
PropagationFlags      : InheritOnly
```

Why I know that this is the appropriate entry? You should have an eye on the ObjectType.

```powershell
$ExtendedRight["reset password"]

Guid
----
00299570-246d-11d0-a768-00aa006e0529
```

That’s It for this blog post.