---
title: 'Signing PowerShell scripts'
date: '2016-06-13T12:10:34+01:00'
categories: [PowerShell]
tags: [PowerShell]
---

In this post i will tell you why It’s important to sign your skripts.

If we look at a clean installed pc, PowerShell scripts can’t run by default.
This is blocked by Microsoft due to security reasons.
If you download a PowerShell skript from the internet and try to run it, It won’t work.
Even If you unblock the skript, It won’t work. So there are two possibilities to run scripts:

- Sign scripts
- Change the ExecutionPolicy (only for testing purposes)

So what is that ExecutionPolicy?

This is a method to prevent you from running malicious code from the internet or from an untrusted source.

You can set the following execution policies:

- **RemoteSigned**: Run scripts that has created locally. Scripts from UNC-paths or the internet has been singed by a trusted publisher
- **Unrestricted**: You can run every script from every source. No signing required
- **AllSigned**: Every script that runs needs to be singed by a trusted publisher.
- **Restricted**: No script can be executed on that system.

You can get all ExecutionPolicies for all scopes by running the following command:

```powershell
Get-ExecutionPolicy -List | Format-Table -AutoSize
```

You will get a table with Scopes and the current ExecutionPolicy.

| Scope         | ExecutionPolicy  |
|-------------- |------------------|
| MachinePolicy | Undefined        |
| UserPolicy    | Undefined        |
| Process       | Undefined        |
| CurrentUser   | Undefined        |
| LocalMachine  | Undefined        |

Explanation of the Scopes:

- Machine Policy: This can be set by Group Policy and applies to all users (Computer Configuration -&gt; Administrative Templates -&gt; Windows Components -&gt; Windows PowerShell -&gt; Turn On Script Execution)
- User Policy: This can be set by Group Policy and applies to the current user (User Configuration -&gt; Administrative Templates -&gt; Windows Components -&gt; Windows PowerShell -&gt; Turn On Script Execution)
- Process: The execution eolicy for the current PowerShell session.
- CurrentUser: The execution policy for the current user.
- LocalMachine: The execution policy for all users.

The default scope is LocalMachine. If you set the execution policy with the following command:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Restricted
```

So let’s get into code signing:

there are two methods for signing code:

- with a certificate from a PKI.
- with a self singed certificate.

I won’t cover the self singed certificate part, because if you are in a production environment It’s not recommended.

for the PKI scenario you need to have a PKI installed into your environment and you need a code signing certificate.

If you don’t have that I will show you how to intall it via PowerShell.

- Install the Certificate Authority:

```powershell
Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -KeyLength 2048 -HashAlgorithmName SHA1 -ValidityPeriod Years -ValidityPeriodUnits 3
```

- Add the codesinging Template to the CA:

```powershell
Add-CATemplate -Name 'Code Signing'
```

- Make the certificate availible in the Domain through Group policy:

First you have to issue a certificate. Open a mmc and add the certificates-snap-in.
Go to Personal -&gt; Certificates. Right-Click all Tasks an Click "Request new certificate".

![Reqest_New_Certificate](/assets/pictures/2016-06-13/Reqest_New_Certificate.png)

Click next in the first dialog box. In the window "Select Certificate Enrollment Policy" click next

![Certificate_Enrollment_Policy](/assets/pictures/2016-06-13/Certificate_Enrollment_Policy.png)

Select the "Code Signing" – template. Click on details and select "Properties"

![Code_Signing](/assets/pictures/2016-06-13/Code_Signing.png)

In the properties window go to the "Private Key" – tab and expand the section Key options. Check "Make private key exportable"

![Code_Signing_Certificate_Properties](/assets/pictures/2016-06-13/Code_Signing_Certificate_Properties.png)

Select the OK-button and click "Enroll".

Now we have to export the certificate. Right-click on the certificate -&gt; All Tasks -&gt; Export.

![Export_Certificate](/assets/pictures/2016-06-13/Export_Certificate.png)

Click next on all screens and save the certificate on the harddrive.

Now we need to create a Group Policy. Open the Group Policy Management and add a new Group Policy. In my case i will create it on the root level of the domain.
Right-click your domain name and click "Create a GPO in this domain, and Link it here"

![ADD_GPO](/assets/pictures/2016-06-13/ADD_GPO.png)

Give the Group policy a name. Right-click the policy and click edit

![GPO_Edit](/assets/pictures/2016-06-13/GPO_Edit.png)

Expand "Computer Configuration -&gt; Policies -&gt; Windows Settings -&gt; Security Settings -&gt; Public Key Policies -&gt; Trusted Publishers" right-click "Import"

![GPO_Import_Certificate](/assets/pictures/2016-06-13/GPO_Import_Certificate.png)

Select the path to the certificate that you saved on the harddrive and click next on all screens. If the process is complete you can check if it was successful by clicking "Trusted Publishers". You now should see the certificate.

![GPO_check_certificate](/assets/pictures/2016-06-13/GPO_check_certificate.png)

So the next time the clients update the policy it is placed into the "Trusted Publishers" store.

To proof that, let’s look at a client before the group policy update.

![Check_Client_Before_Gp_Update](/assets/pictures/2016-06-13/Check_Client_Before_Gp_Update.png)

Now let’s make a group policy update by opening a PowerShell console and type in

```bash
gpupdate /force
```

![Update_GPO](/assets/pictures/2016-06-13/Update_GPO.png)

If I now refresh my "Trusted Publishers" – certificate store I will find the new certificate.

![Check_Client_After_Gp_Update](/assets/pictures/2016-06-13/Check_Client_After_Gp_Update.png)

If you now want to sign a script on another computer, you also need the code signing certificate that we created earlier and import it into your "Personal" store.

If you want to sign a script with that certificate use the following code:

```powershell
# Get the codesigning cert
$cert=(Get-ChildItem cert:currentuser\my\ -CodeSigningCert)

# Sign the script
Set-AuthenticodeSignature -Certificate $cert -FilePath [PATH TO SCRIPT]
```

If you now copy the script to another server and run it should work.