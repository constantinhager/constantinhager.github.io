---
id: 24
title: 'Manage Hyper-V Hosts in a workgroup environment'
date: '2016-02-07T03:40:17+01:00'
categories: [Windows Server]
tags: [Windows Server]
---

If you try to connect to a Hyper-V Host in a workgroup environment, you get the following error:

![Hyper-V-Error](/assets/pictures/2016-02-07/Hyper-V-Fehler.png)

## Target machine

to connect to the Hyper-V environment you need to have WinRM enabled. It’s only enabled by default on Windows Servers. To activate WinRM on the client you have to open a PowerShell with administrative rights and use the following CMD-Let:


```powershell
Enable-PSRemoting
```

If It is sucessful you will get the following picture:

![Enable-PSRemoting](/assets/pictures/2016-02-07/Enable-PSRemoting.png)

If you have more networkdevices installed and one of them is configured with the profile "Public" the command will fail by the step of configuring the firewall rules. To solve the issue we have to identify the InterfaceIndex of the networkcard that raises the error. You can achieve this by using the following CMD-Let:

```powershell
Get-NetConnectionProfile
```

All networkcards are listed now. If you look at the "NetworkCategory" property of the listed Networkcards write down all the "InterfaceIndexes" where the "NetworkCategory" is Public. We need them in the following PowerShell command.

![Get-NetConnectionProfile](/assets/pictures/2016-02-07/Get-NetconnectionProfile.png)

In this command we set the "InterfaceIndex" to 10:

```powershell
Set-NetConnectionProfile -InterfaceIndex 10 -NetworkCategory Private
```

Now rerun

```powershell
Enable-PSRemoting
```

It should run without any problem now.
The next step is to enable a firewall rule in the Windows Firewall.
The Following PowerShell-command helps here:

```powershell
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
```

If we are on german systems we have other DisplayGroups. Use this command instead.

```powershell
Enable-NetFirewallRule -DisplayGroup "Windows-Remoteverwaltung"
```

## The Source Machine

You also have to enable the firewallrule for PowerShell remoting.

Run the following command:

For english systems:

```powershell
Enable-NetFirewallRule -DisplayGroup “Windows Remote Management”
```

For german systems:

```powershell
Enable-NetFirewallRule -DisplayGroup “Remotevolumeverwaltung”
```

If you don’t have any DNS/DCHP service at home you have to edit the hosts file as well.
Therefore you have to open notepad as an administrator and open the following file:

C:\\Windows\\system32\\drivers\\etc\\hosts.

Fist type in the IP-Address of the target system. Type Tab key and then type the PC-Name of the target system. Save the file and close it.
Finally you have to add the target computername to the trusted hosts in WinRM.

You can achieve this by using this PowerShell-command:

```powershell
Set-Item WSMman:\localhost\Client\TrustedHosts -Value <Name of Hyper-V-HOST> -Concatenate -Force
```

Bevore you connect to the HyperV-Sever you have to add a user with the exact same credentials as your source computer.
If you want to use another user account you can use the cmdkey command.

You can use this command:

```bash
cmdkey /add:<HYPER-V-SERVERNAME> /user:<LOCAL USER ON HYPER-V-SERVER> /pass
```

After this you only have to type in the password for the user.
The very last step for this is open dcomcnfg.

Go to Componentservices -&gt; Computer -&gt; My Computer. Right Click -&gt; Properties
-&gt; Com-Security -&gt; Edit Limits.

Make sure that Anonymus Logon has Remote Access Permission enabled.

If you try now to reconnect to the target computer using Hyper-V manager the computer will now show up in the manager.
You can now start adding VMs or Switches to the system.