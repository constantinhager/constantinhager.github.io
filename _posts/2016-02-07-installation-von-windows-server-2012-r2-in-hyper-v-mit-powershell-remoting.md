---
title: 'Installation of Testenvironemt in Hyper-V through PowerShell Remoting'
date: '2016-02-07T05:55:18+01:00'
categories: [PowerShell, Hyper-V ]
tags: [PowerShell]
---

In the blogpost [Manage Hyper-V Hosts in a workgroup environment]({% post_url 2016-02-07-managen-von-hyper-v-hosts-ohne-active-directory %}) I described how to connect two Windows 10 devices in a workgroup environment.

I describe the following steps:

1. Connect to the target machine via PowerShell remoting
2. Set up the testenvironment (Configure some virtual switches (for internal traffic and external traffic), add the necessary VMs).

## Connect to the target machine via PowerShell remoting:


```powershell
Enter-PSSession HYPER-V-HOSTNAME
```

## Set up the test environment (Virtual switches and virtual machines)

The test environment will consist of the following ressources:

4 VMs

- 1 DomainController
- 2 SQL Server
- 1 Windows Server configured as witness

Count of Harddisks:

- DomainController: 1 HDD
- SQL1: 3 HDDs
- SQL2: 3 HHDs
- CLU: 1 HDD

Virtual switches

- One switch for the internal traffic (Private)
- One switch for the traffic between the Guest and the Host (Internal)

To configure this environment you can use this PowerShell script:


```powershell
################################### Funktionsblock ########################################

# Check Functions
function Check-VMSwitch([string]$SwitchName)
{
    $Testswitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue

    if($Testswitch.Count -eq 0)
    {
        return $false
    }
    else
    {
        return $true
    }
}

function Check-IfVMIsThere([string]$VMName)
{
    $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue

    if($VM)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Check-IfNetworkAdapterIsConnectedToVM([string]$VmName, [string]$SwitchName)
{
    $ret_switchname = (Get-VM -Name $VmName | Get-VMNetworkAdapter).SwitchName

    if($ret_switchname -eq $SwitchName)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Check-IfVMDVDDrirveHasISO([string]$VMName)
{
    $ret_path = (Get-VMDvdDrive -VMName $VMName).Path

    if([string]::IsNullOrEmpty($ret_path))
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Check-IfVHDXIsAttachedToVM([string]$VMName, [string]$Path)
{
    $ret_path = (Get-VMHardDiskDrive -VMName $VMName).Path

    if($ret_path -like $Path)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Check-IfFolderExists([string]$FolderPath)
{
    if(Test-Path $FolderPath)
    {
        return $true
    }
    else
    {
        return $false
    }
}

# Create Functions

function Create-VHDX([string]$PathToVHDX, [int64]$SizeBytes)
{
    New-VHD -Path $PathToVHDX -SizeBytes $SizeBytes
}

# Create Functions Ende

# Add Functions

function Add-VSwitch([string]$SwitchName, $SwitchType, [string]$Notes)
{
    Write-Output "Switch $SwitchName wird angelegt"
    New-VMSwitch -Name $SwitchName -SwitchType $SwitchType -Notes $Notes
}

function Add-Folder([string]$FolderPath)
{
    Write-Output "Odner $FolderPath wird angelegt"
    New-Item -ItemType Directory -Path $FolderPath
}

function Add-VM ([string]$VMName, [string]$VMPath, [int64]$MemoryStartupBytes, [string]$VHDPath, [int64]$NewVHDSizeBytes, [string]$SwitchName)
{
    Write-Output "VM $VMName wird erstellt"
    New-VM -Name $VMName -Path $VMPath -MemoryStartupBytes $MemoryStartupBytes -NewVHDPath $VHDPath -NewVHDSizeBytes $NewVHDSizeBytes -SwitchName $SwitchName
}

function Add-NetworkAdapterToVM([string]$VMName, [string]$SwitchName)
{
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName
}

function Add-ISOToDVDDrive([string]$VMName, [string]$ISOPath)
{
    Set-VMDvdDrive -VMName $VMName -Path $ISOPath
}

function Add-VHDXTOVM([string]$VMName, [string]$PathToVHDX)
{
    Add-VMHardDiskDrive -VMName $VMName -Path $PathToVHDX
}

# Ende Add Functions

# Remove Function

function Remove-ISOFromVMDVDDrive([string]$VMName)
{
    Get-VM -Name $VMName | Get-VMDvdDrive | Set-VMDvdDrive -Path $null

    $ret_isrealyempty = Check-IfVMDVDDrirveHasISO -VMName $VMName

    if($ret_isrealyempty)
    {
        Write-Output "ISO erfolgreich unmounted."
        return $true
    }
    else
    {
        Write-Output "ISO Noch vorhanden."
        return $false
    }
}

# Remove Function Ende

# ################################# Variablendeklarationen ################################

$SQL1 = "SRV-SQL1"
$SQL2 = "SRV-SQL2"
$DC = "SRV-DC"
$CLU = "SRV-CLU"

$DCRAM = 2GB
$CLURAM = 2GB
$SQL1RAM = 4GB
$SQL2RAM = 4GB

$DCVHD = 80GB
$CLUVHD = 80GB

$SQL1VHD_OS = 60GB
$SQL1VHD_DB = 20GB
$SQL1VHD_DB_Name = "sql1db.vhdx"
$SQL1VHD_LOG = 20GB
$SQL1VHD_LOG_Name = "sql1log.vhdx"
$SQL1VHD_BACKUP = 20GB
$SQL1VHD_BACKUP_Name = "sql1backup.vhdx"

$SQL2VHD_OS = 60GB
$SQL2VHD_DB = 20GB
$SQL2VHD_DB_Name = "sql2db.vhdx"
$SQL2VHD_LOG = 20GB
$SQL2VHD_LOG_Name = "sql2log.vhdx"
$SQL2VHD_BACKUP = 20GB
$SQL2VHD_BACKUP_Name = "sql2backup.vhdx"

$VMLOC = "C:\HyperV"

$ISODIR = "C:\Temp\Windows Server 2012 R2.ISO"

$NetworkSwitch_Private = "VMTraffic"
$NetworkSwitch_Private_Notes = "Network for VMs only"
$NetworkSwitch_Private_Type = "Private"
$NetworkSwitch_Internal = "internalswitch"
$NetworkSwitch_Internal_Notes = "Traffic between VMs and the host"
$NetworkSwitch_Internal_Type = "Internal"

############################### Variablen Ende ##########################################

# Test, ob Ordner existiert. Wenn ja -> Keine Aktion, Wenn nicht -> Ordner wird erstellt.
$VMLOC_Exists = Check-IfFolderExists -FolderPath $VMLOC

if($VMLOC_Exists)
{
    Write-Output "Verzeichnis $VMLOC existiert bereits."
}
else
{
    Write-Output "Verzeichnis $VMLOC wird erstellt."
    Add-Folder -FolderPath $VMLOC
}

# Testen, ob es einen virtuellen Switch mit dem Namen $NetworkSwitch1
# bereits gibt. Gibt es ihn nicht wird er angelegt. Gibt es ihn
# wird nur eine Meldung ausgegeben das es diesen schon gibt.
$PrivateSwitchIsThere = Check-VMSwitch -SwitchName $NetworkSwitch_Private
$InternalSwitchIsThere = Check-VMSwitch -SwitchName $NetworkSwitch_Internal

if($PrivateSwitchIsThere)
{
    Write-Output "Switch $NetworkSwitch_Private ist bereits vorhanden."
}
else
{
    Write-Output "Switch $NetworkSwitch_Internal wird erstellt."
    Add-VSwitch -SwitchName $NetworkSwitch_Private -SwitchType $NetworkSwitch_Private_Type -Notes $NetworkSwitch_Private_Notes
}


if($InternalSwitchIsThere)
{
    Write-Output "Switch $NetworkSwitch_Internal ist bereits vorhanden."
}
else
{
    Write-Output "Switch $NetworkSwitch_Internal wird erstellt."
    Add-VSwitch -SwitchName $NetworkSwitch_Internal -SwitchType $NetworkSwitch_Internal_Type -Notes $NetworkSwitch_Internal_Notes
}


######################### Erstellen der virtuellen Maschinen #########################

# Prüfen, ob VMs bereits vorhanden. Wenn schon vorhanden, dann soll diese auch nicht
# erstellt werden.
$DCExists = Check-IfVMIsThere -VMName $DC
$SQL1Exists = Check-IfVMIsThere -VMName $SQL1
$SQL2Exists = Check-IfVMIsThere -VMName $SQL2
$CLUExists = Check-IfVMIsThere -VMName $CLU

# Maschine SRV-DC wird erstellt wenn sie noch nicht existiert
if($DCExists)
{
    Write-Output "VM $DC Existiert bereits."
}
else
{
    Write-Output "VM $DC wird erstellt."
    Add-VM -VMName $DC -VMPath $VMLOC -MemoryStartupBytes $DCRAM -VHDPath "$VMLOC\dc.vhdx" -NewVHDSizeBytes $DCVHD -SwitchName $NetworkSwitch_Private
}

# Maschine SRV-SQL1 wird erstellt wenn sie noch nicht existiert
if($SQL1Exists)
{
    Write-Output "VM $SQL1 Existiert bereits."
}
else
{
    Write-Output "VM $SQL1 wird erstellt."
    Add-VM -VMName $SQL1 -VMPath $VMLOC -MemoryStartupBytes $SQL1RAM -VHDPath "$VMLOC\sql1.vhdx" -NewVHDSizeBytes $SQL1VHD_OS -SwitchName $NetworkSwitch_Private
}

# Maschine SRV-SQL2 wird erstellt wenn sie noch nicht existiert
if($SQL2Exists)
{
    Write-Output "VM $SQL2 Existiert bereits."
}
else
{
    Write-Output "VM $SQL2 wird erstellt."
    Add-VM -VMName $SQL2 -VMPath $VMLOC -MemoryStartupBytes $SQL2RAM -VHDPath "$VMLOC\sql2.vhdx" -NewVHDSizeBytes $SQL2VHD_OS -SwitchName $NetworkSwitch_Private
}

# Maschine SRV-SQL2 wird erstellt wenn sie noch nicht existiert
if($CLUExists)
{
    Write-Output "VM $CLU Existiert bereits."
}
else
{
    Write-Output "VM $CLU wird erstellt."
    Add-VM -VMName $CLU -VMPath $VMLOC -MemoryStartupBytes $CLURAM -VHDPath "$VMLOC\clu.vhdx" -NewVHDSizeBytes $CLUVHD -SwitchName $NetworkSwitch_Private
}


# Hinzufügen einer weiteren Netzwerkkarte für alle VMs und an den Internen Switch binden.
# Es muss erst geprüft werden, ob die Netzwerkkarte bereits an die VM gebunden ist.
$DCNAExits = Check-IfNetworkAdapterIsConnectedToVM -VmName $DC -SwitchName $NetworkSwitch_Internal
$SQL1NAExits = Check-IfNetworkAdapterIsConnectedToVM -VmName $SQL1 -SwitchName $NetworkSwitch_Internal
$SQL2NAExits = Check-IfNetworkAdapterIsConnectedToVM -VmName $SQL2 -SwitchName $NetworkSwitch_Internal
$CLUNAExits = Check-IfNetworkAdapterIsConnectedToVM -VmName $CLU -SwitchName $NetworkSwitch_Internal

# Ist dies bei SRV-DC nicht der Fall wird die Netzwerkkarte erstellt und an den Switch gebunden
if($DCNAExits)
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal ist bereits an die VM $DC gebunden."
}
else
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal wird an die VM $DC gebunden."
    Add-NetworkAdapterToVM -VMName $DC -SwitchName $NetworkSwitch_Internal
}

# Ist dies bei SRV-SQL1 nicht der Fall wird die Netzwerkkarte erstellt und an den Switch gebunden
if($SQL1NAExits)
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal ist bereits an die VM $SQL1 gebunden."
}
else
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal wird an die VM $SQL1 gebunden."
    Add-NetworkAdapterToVM -VMName $SQL1 -SwitchName $NetworkSwitch_Internal
}

# Ist dies bei SRV-SQL2 nicht der Fall wird die Netzwerkkarte erstellt und an den Switch gebunden
if($SQL2NAExits)
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal ist bereits an die VM $SQL2 gebunden."
}
else
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal wird an die VM $SLQ2 gebunden."
    Add-NetworkAdapterToVM -VMName $SQL2 -SwitchName $NetworkSwitch_Internal
}

if($CLUNAExits)
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal ist bereits an die VM $CLU gebunden."
}
else
{
    Write-Output "Der NetzwerkSwitch $NetworkSwitch_Internal wird an die VM $CLU gebunden."
    Add-NetworkAdapterToVM -VMName $CLU -SwitchName $NetworkSwitch_Internal
}

# ISO-Datei an VMs binden
# Überprüfen, ob bereits ein ISO-File gemountet
$DCCheckISO = Check-IfVMDVDDrirveHasISO -VMName $DC
$SQL1CheckISO = Check-IfVMDVDDrirveHasISO -VMName $SQL1
$SQL2CheckISO = Check-IfVMDVDDrirveHasISO -VMName $SQL2
$CLUCheckISO = Check-IfVMDVDDrirveHasISO -VMName $CLU

# Wenn eine ISO gemoutet ist, soll diese ausgeworfen werden und die ISO von Pfad $ISODIR soll gemounted werden
if($DCCheckISO)
{
    Write-Output "ISO $ISODIR wird gemounted."
    Add-ISOToDVDDrive -VMName $DC -ISOPath $ISODIR
}
else
{
    Write-Output "Es ist eine ISO vorhanden. Diese wird jetzt dismouted."
    $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $DC
    if($ret_removeISO)
    {
        Write-Output "ISO $ISODIR wird gemouted"
        Add-ISOToDVDDrive -VMName $DC -ISOPath $ISODIR
    }
    else
    {
        $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $DC
    }
}

# Wenn eine ISO gemoutet ist, soll diese ausgeworfen werden und die ISO von Pfad $ISODIR soll gemounted werden
if($SQL1CheckISO)
{
    Write-Output "ISO $ISODIR wird gemounted."
    Add-ISOToDVDDrive -VMName $SQL1 -ISOPath $ISODIR
}
else
{
    Write-Output "Es ist eine ISO vorhanden. Diese wird jetzt dismouted."
    $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $SQL1
    if($ret_removeISO)
    {
        Write-Output "ISO $ISODIR wird gemouted"
        Add-ISOToDVDDrive -VMName $SQL1 -ISOPath $ISODIR
    }
    else
    {
        $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $SQL1
    }
}

# Wenn eine ISO gemoutet ist, soll diese ausgeworfen werden und die ISO von Pfad $ISODIR soll gemounted werden
if($SQL2CheckISO)
{
    Write-Output "ISO $ISODIR wird gemounted."
    Add-ISOToDVDDrive -VMName $SQL2 -ISOPath $ISODIR
}
else
{
    Write-Output "Es ist eine ISO vorhanden. Diese wird jetzt dismouted."
    $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $SQL2
    if($ret_removeISO)
    {
        Write-Output "ISO $ISODIR wird gemouted"
        Add-ISOToDVDDrive -VMName $SQL2 -ISOPath $ISODIR
    }
    else
    {
        $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $SQL2
    }
}

if($CLUCheckISO)
{
    Write-Output "ISO $ISODIR wird gemounted."
    Add-ISOToDVDDrive -VMName $CLU -ISOPath $ISODIR
}
else
{
    Write-Output "Es ist eine ISO vorhanden. Diese wird jetzt dismouted."
    $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $CLU
    if($ret_removeISO)
    {
        Write-Output "ISO $ISODIR wird gemouted"
        Add-ISOToDVDDrive -VMName $CLU -ISOPath $ISODIR
    }
    else
    {
        $ret_removeISO = Remove-ISOFromVMDVDDrive -VMName $CLU
    }
}

# Erstellen der Festplatten

# Erstellen der Pfade für SQL1
$PfadSQL1DB = "$VMLOC" + "\" + $SQL1VHD_DB_Name
$PfadSQL1LOG = "$VMLOC" + "\" + $SQL1VHD_LOG_Name
$PfadSQL1BACKUP = "$VMLOC" + "\" + $SQL1VHD_BACKUP_Name

# Erstellen der Pfade für SQL2
$PfadSQL2DB = "$VMLOC" + "\" + $SQL2VHD_DB_Name
$PfadSQL2LOG = "$VMLOC" + "\" + $SQL2VHD_LOG_Name
$PfadSQL2BACKUP = "$VMLOC" + "\" + $SQL2VHD_BACKUP_Name

# Testen ob die VHDX bereits existiert
if(Check-IfFolderExists -FolderPath $PfadSQL1DB)
{
    Write-Output "VHD $PfadSQL1DB existiert bereits"
}
else
{
    Create-VHDX -PathToVHDX $PfadSQL1DB -SizeBytes $SQL1VHD_DB
    Add-VHDXTOVM -VMName $SQL1 -PathToVHDX $PfadSQL1DB
}

# Testen ob die VHDX bereits existiert
if(Check-IfFolderExists -FolderPath $PfadSQL1LOG)
{
    Write-Output "VHD $PfadSQL1LOG existiert bereits"
}
else
{
    Create-VHDX -PathToVHDX $PfadSQL1LOG -SizeBytes $SQL1VHD_LOG
    Add-VHDXTOVM -VMName $SQL1 -PathToVHDX $PfadSQL1LOG
}

# Testen ob die VHDX bereits existiert
if(Check-IfFolderExists -FolderPath $PfadSQL1BACKUP)
{
    Write-Output "VHD $PfadSQL1BACKUP existiert bereits"
}
else
{
    Create-VHDX -PathToVHDX $PfadSQL1BACKUP -SizeBytes $SQL1VHD_BACKUP
    Add-VHDXTOVM -VMName $SQL1 -PathToVHDX $PfadSQL1BACKUP
}

# Testen ob die VHDX bereits existiert
if(Check-IfFolderExists -FolderPath $PfadSQL2DB)
{
    Write-Output "VHD $PfadSQL2DB existiert bereits"
}
else
{
    Create-VHDX -PathToVHDX $PfadSQL2DB -SizeBytes $SQL2VHD_DB
    Add-VHDXTOVM -VMName $SQL2 -PathToVHDX $PfadSQL2DB
}

# Testen ob die VHDX bereits existiert
if(Check-IfFolderExists -FolderPath $PfadSQL2LOG)
{
    Write-Output "VHD $PfadSQL2LOG existiert bereits"
}
else
{
    Create-VHDX -PathToVHDX $PfadSQL2LOG -SizeBytes $SQL2VHD_LOG
    Add-VHDXTOVM -VMName $SQL2 -PathToVHDX $PfadSQL2LOG
}

# Testen ob die VHDX bereits existiert
if(Check-IfFolderExists -FolderPath $PfadSQL2BACKUP)
{
    Write-Output "VHD $PfadSQL2BACKUP existiert bereits"
}
else
{
    Create-VHDX -PathToVHDX $PfadSQL2BACKUP -SizeBytes $SQL2VHD_BACKUP
    Add-VHDXTOVM -VMName $SQL2 -PathToVHDX $PfadSQL2BACKUP
}
```

Also I will show you the setup of the environment (Install scripts, Install SQL-Server from commandline and so on).