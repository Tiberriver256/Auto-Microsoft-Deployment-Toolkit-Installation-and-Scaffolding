#Requires -Version 5.0
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    LEGACY-2016: Installs MDT 2013 and scaffolds a deployment share (reference only).
.DESCRIPTION
    2016-era automation for MDT 2013 Update 2 targeting Windows 7 / 8.1 / 10
    (1507-era) eval media. Download sources are believed dead; see
    docs/DOWNLOADS.md. Review the README before running.
    Requires elevation. The task-sequence local-admin password must be passed
    explicitly via -TaskSequenceAdminCredential (SecureString password);
    it is never hardcoded.
.EXAMPLE
    $cred = Get-Credential -Message 'Local admin password for MDT task sequences'
    .\MDTAutoInstall.ps1 -ISOPath 'C:\MDT\ISOs' -TaskSequenceAdminCredential $cred
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ISOPath = 'C:\MDT\ISOs',

    [Parameter()]
    [string]$DeploymentSharePath = 'C:\DeploymentShare',

    [Parameter()]
    [string]$DeploymentShareName = 'DeploymentShare$',

    [Parameter()]
    [string]$DeploymentShareNetworkPath = "\\$env:COMPUTERNAME\DeploymentShare$",

    [Parameter()]
    [string[]]$Servers = @('localhost'),

    [Parameter()]
    [string]$RegisteredFullName = 'Change Me',

    [Parameter()]
    [string]$RegisteredOrgName = 'Change Me',

    [Parameter()]
    [string]$RegisteredHomePage = 'https://example.com',

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$TaskSequenceAdminCredential,

    [Parameter()]
    [hashtable]$ExpectedFileHashes = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# TLS 1.2+ for all downloads (legacy http:// sources must be replaced; see docs/DOWNLOADS.md).
[Net.ServicePointManager]::SecurityProtocol = ([Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12)

if (-not (Test-Path -LiteralPath $ISOPath)) {
    New-Item -Path $ISOPath -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $DeploymentSharePath)) {
    if ($PSCmdlet.ShouldProcess($DeploymentSharePath, 'Create deployment share directory')) {
        New-Item -Path $DeploymentSharePath -ItemType Directory -Force | Out-Null
    }
}

function Assert-FileSHA256 {
    <#
    .SYNOPSIS
        Verifies a staged download against an expected SHA256 hash.
    .DESCRIPTION
        Looks up (Split-Path -Leaf $Path) in $ExpectedFileHashes. If no entry
        exists, writes a warning and returns (legacy mode). If an entry exists
        and mismatches, throws. Populate -ExpectedFileHashes before real runs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$ExpectedHashes
    )
    $leaf = Split-Path -Leaf $Path
    if (-not $ExpectedHashes.ContainsKey($leaf)) {
        Write-Warning "No expected SHA256 registered for '$leaf'. Add it to -ExpectedFileHashes (see docs/DOWNLOADS.md)."
        return
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedHashes[$leaf]) {
        throw "SHA256 mismatch for '$leaf'. Expected $($ExpectedHashes[$leaf]), got $actual."
    }
}

# Plaintext is required by the MDT task-sequence cmdlet; derive it only here
# from the SecureString credential and clear it at the end of the script.
$TaskSequenceAdminPlaintext = $TaskSequenceAdminCredential.GetNetworkCredential().Password

$InstalledModules = Get-Module -ListAvailable

if(!($InstalledModules | Where-Object {$_.Name -match "PoshProgressBar"}))
{
    Install-Module PoshProgressBar -Verbose
}

# LEGACY cosmetic icon for the progress bar. Delete this block if the URL 404s.
$FaviconPath = Join-Path $ISOPath 'favicon.ico'
if (-not (Test-Path -LiteralPath $FaviconPath)) {
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Tiberriver256/Tiberriver256.GitHub.io/master/favicon.ico' -OutFile $FaviconPath
}
Assert-FileSHA256 -Path $FaviconPath -ExpectedHashes $ExpectedFileHashes

$PoshProgressBar = New-ProgressBar -MaterialDesign -Theme Dark -IsIndeterminate $True -Type Circle -IconPath "$FaviconPath" -Size Medium

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Installing xPSDesiredStateConfiguration"

if(!($InstalledModules | Where-Object {$_.Name -match "xPSDesiredStateConfiguration"}))
{
    Install-Module xPSDesiredStateConfiguration -Verbose
}

Configuration DeployMDT2013Lab    
{ 
 
  param(
    [Parameter(Mandatory=$true)]
    [String[]]$Servers,
    [String]$ISOPath
  )
 
 Import-DscResource -ModuleName PSDesiredStateConfiguration
 Import-DscResource -ModuleName xPSDesiredStateConfiguration

  Node $Servers
  { 
    

    xRemoteFile DownloadIMDisk
    {
        # LEGACY WARNING: plain-HTTP legacy host (see docs/DOWNLOADS.md entry 2). Replace with HTTPS + ExpectedFileHashes before use.
        URI = "http://www.ltr-data.se/files/imdiskinst.exe"
        DestinationPath = "$ISOPath\imdiskinst.exe"
        MatchSource = $False
    }

    xRemoteFile DownloadMDT2013
    {
        URI = "https://download.microsoft.com/download/3/0/1/3012B93D-C445-44A9-8BFB-F28EB937B060/MicrosoftDeploymentToolkit2013_x64.msi"
        DestinationPath = "$ISOPath\MicrosoftDeploymentToolkit2013_x64.msi"
        MatchSource = $False
    }

    xRemoteFile DownloadPacker
    {
    
        URI = "https://releases.hashicorp.com/packer/0.9.0/packer_0.9.0_windows_amd64.zip"
        DestinationPath = "$ISOPath\packer_0.9.0_windows_amd64.zip"
        MatchSource = $False
    
    }

    Archive ExtractPacker
    {
    
        DependsOn = "[xRemoteFile]DownloadPacker"
        Path = "$ISOPath\packer_0.9.0_windows_amd64.zip"
        Destination = "$ISOPath\Packer"
        
    }

    xRemoteFile DownloadWSUSOfflineUpdater
    {
    
        # LEGACY WARNING: plain-HTTP legacy host (see docs/DOWNLOADS.md entry 5). Replace with HTTPS + ExpectedFileHashes before use.
        URI = "http://download.wsusoffline.net/wsusoffline106.zip"
        DestinationPath = "$ISOPath\wsusoffline106.zip"
        MatchSource = $False
    
    }

    Archive ExtractWSUSOfflineUpdater
    {
    
        DependsOn = "[xRemoteFile]DownloadWSUSOfflineUpdater"
        Path = "$ISOPath\wsusoffline106.zip"
        Destination = "$ISOPath\WSUSOfflineUpdater"
        
    }

    Package InstallMDT2013
    {

        DependsOn = "[xRemoteFile]DownloadMDT2013"
        Name = "Microsoft Deployment Toolkit 2013 Update 2 (6.3.8330.1000)"
        Path =  "$ISOPath\MicrosoftDeploymentToolkit2013_x64.msi"
        ProductId = '{F172B6C7-45DD-4C22-A5BF-1B2C084CADEF}'
        Arguments = "/qn"
        Ensure = "Present"

    }

    xRemoteFile Win7EnterPriseISO
    {
        # LEGACY WARNING: Windows 7 eval, EOL + plain HTTP (see docs/DOWNLOADS.md entry 6).
        URI = "http://care.dlservice.microsoft.com/dl/download/evalx/win7/x64/EN/7600.16385.090713-1255_x64fre_enterprise_en-us_EVAL_Eval_Enterprise-GRMCENXEVAL_EN_DVD.iso"
        DestinationPath = "$ISOPath\Win7EnterpriseTrialx64.iso"
        MatchSource = $False
    }

    xRemoteFile Win81EnterPriseISO
    {
        # LEGACY WARNING: Windows 8.1 eval, EOL + plain HTTP (see docs/DOWNLOADS.md entry 7).
        URI = "http://care.dlservice.microsoft.com/dl/download/5/3/C/53C31ED0-886C-4F81-9A38-F58CE4CE71E8/9200.16384.WIN8_RTM.120725-1247_X64FRE_ENTERPRISE_EVAL_EN-US-HRM_CENA_X64FREE_EN-US_DV5.ISO"
        DestinationPath = "$ISOPath\Win81EnterpriseTrialx64.iso"
        MatchSource = $False
    }

    xRemoteFile Win10EnterPriseISO
    {
        # LEGACY WARNING: Windows 10 1507 eval, superseded + plain HTTP (see docs/DOWNLOADS.md entry 8).
        URI = "http://care.dlservice.microsoft.com/dl/download/C/3/9/C399EEA8-135D-4207-92C9-6AAB3259F6EF/10240.16384.150709-1700.TH1_CLIENTENTERPRISEEVAL_OEMRET_X64FRE_EN-US.ISO"
        DestinationPath = "$ISOPath\Win10EnterpriseTrialx64.iso"
        MatchSource = $False
    }

  } 
}

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Starting DSC Config to download and install MDT and toolset"
DeployMDT2013Lab -Servers $Servers -OutputPath $ISOPath -ISOPath $ISOPath

Start-DscConfiguration -Path $ISOPath -wait -Verbose -Force

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Installing IMDisk for mounting ISOs"
if( ! (Test-Path C:\Windows\System32\imdisk.exe) )
{

    Start-Process -FilePath $ISOPath\imdiskinst.exe -ArgumentList "-y" -Wait

}

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Creating deployment share at $DeploymentSharePath"

#region Extracting ISOs and importing into MDT

New-Item -Path $DeploymentSharePath -ItemType directory -Force
New-SmbShare -Name $DeploymentShareName -Path $DeploymentSharePath -FullAccess Administrators
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
new-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $DeploymentSharePath -Description "MDT Deployment Share" -NetworkPath $DeploymentShareNetworkPath -Verbose | add-MDTPersistentDrive -Verbose
new-item -path "DS001:\Operating Systems" -enable "True" -Name "ISO No Updates" -Comments "This folder holds WIM files created from the ISOs. These have no Windows updates installed and no 3rd party software." -ItemType "folder" -Verbose

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Importing Windows 7 x64 OS"

Start-Process -FilePath "C:\windows\System32\imdisk.exe" -ArgumentList @("-a", "-f $ISOPath\Win7EnterpriseTrialx64.iso", "-m A:") -Wait

Write-Output "Importing Windows 7 Image"
import-mdtoperatingsystem -path "DS001:\Operating Systems\ISO No Updates" -SourcePath "A:\" -DestinationFolder "Windows 7 x64" -Verbose

Start-Process -FilePath "C:\windows\System32\imdisk.exe" -ArgumentList @("-D", "-m A:") -Wait


Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Importing Windows 8.1 x64 OS"

Start-Process -FilePath "C:\windows\System32\imdisk.exe" -ArgumentList @("-a", "-f $ISOPath\Win81EnterpriseTrialx64.iso", "-m A:") -Wait

Write-Output "Importing Windows 8.1 Image"
import-mdtoperatingsystem -path "DS001:\Operating Systems\ISO No Updates" -SourcePath "A:\" -DestinationFolder "Windows 8.1 x64" -Verbose

Start-Process -FilePath "C:\windows\System32\imdisk.exe" -ArgumentList @("-D", "-m A:") -Wait


Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Importing Windows 10 x64 OS"

Start-Process -FilePath "C:\windows\System32\imdisk.exe" -ArgumentList @("-a", "-f $ISOPath\Win10EnterpriseTrialx64.iso", "-m A:") -Wait

Write-Output "Importing Windows 10 Image"
import-mdtoperatingsystem -path "DS001:\Operating Systems\ISO No Updates" -SourcePath "A:\" -DestinationFolder "Windows 10 x64" -Verbose

Start-Process -FilePath "C:\windows\System32\imdisk.exe" -ArgumentList @("-D", "-m A:") -Wait

#endregion

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Configuring WinPE Settings"

@'
[Settings]
Priority=Default
Properties=MyCustomProperty

[Default]
' // Credentials for connecting to network share
UserID=
UserDomain=
UserPassword=

' // Wizard Pages
SkipWizard=NO
SkipAppsOnUpgrade=NO
SkipDeploymentType=NO

SkipComputerName=NO
SkipDomainMembership=NO
' // OSDComputerName = 
' // and
' // JoinWorkgroup = 
' // or
' // JoinDomain = 
' // DomainAdmin = 

SkipUserData=NO
' // UDDir = 
' // UDShare = 
' // UserDataLocation = 

SkipComputerBackup=NO
' // BackupDir = 
' // BackupShare = 
' // ComputerBackupLocation = 

SkipTaskSequence=NO
' // TaskSequenceID="Task Sequence ID Here"

SkipProductKey=NO
' // ProductKey = 
' // Or
' // OverrideProductKey = 
' // Or
' // If using Volume license, no Property is required

SkipPackageDisplay=NO
' // LanguagePacks = 

SkipLocaleSelection=NO
' // KeyboardLocale = 
' // UserLocale = 
' // UILanguage = 

SkipTimeZone=NO
' // TimeZone = 
' // TimeZoneName = 

SkipApplications=NO
' // Applications

SkipAdminPassword=NO
' // AdminPassword

SkipCapture=NO
' // ComputerBackupLocation = 

SkipBitLocker=NO
' // BDEDriveLetter = 
' // BDEDriveSize = 
' // BDEInstall = 
' // BDEInstallSuppress = 
' // BDERecoveryKey = 
' // TPMOwnerPassword = 
' // OSDBitLockerStartupKeyDrive = 
' // OSDBitLockerWaitForEncryption = 

SkipSummary=NO
SkipFinalSummary=NO
SkipCredentials=NO

SkipRoles=NO
' // OSRoles
' // OSRoleServices
' // OSFeatures

SkipBDDWelcome=NO
SkipAdminAccounts=NO
' // Administrators = 

'@ | Out-File (Join-Path $DeploymentSharePath 'Control\CustomSettings.ini') -Encoding ASCII

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Updating Deployment Share"

update-MDTDeploymentShare -path "DS001:" -Verbose


Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Creating decent folder structure"

#region MDT Folders

    new-item -path "DS001:\Operating Systems" `
        -enable "True" `
        -Name "Base OS" `
        -Comments "This will hold base WIM images. Fully patched but no scripts embedded or software installed" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Operating Systems" `
        -enable "True" `
        -Name "Custom OS" `
        -Comments "This will hold customized WIM images. They may contain special software or scripts" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Out-Of-Box Drivers" `
        -enable "True" `
        -Name "WinPE" `
        -Comments "This will hold network and mass storage drivers for the WinPE 5.0 x86 and x64 environment" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Out-Of-Box Drivers" `
        -enable "True" `
        -Name "Windows 7" `
        -Comments "This will hold network and mass storage drivers for the Windows 7 x86 and x64 environment" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Out-Of-Box Drivers" `
        -enable "True" `
        -Name "Windows 8.1" `
        -Comments "This will hold network and mass storage drivers for the Windows 8.1 x86 and x64 environment" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Out-Of-Box Drivers" `
        -enable "True" `
        -Name "Windows 10" `
        -Comments "This will hold network and mass storage drivers for the Windows 10 x86 and x64 environment" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Out-Of-Box Drivers" `
        -enable "True" `
        -Name "Archived" `
        -Comments "This will hold archived and abandoned drivers for the all environments" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages" `
        -enable "True" `
        -Name "Language Packs" `
        -Comments "This is intended to hold language packs for the operatings systems" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages\Language Packs" `
        -enable "True" `
        -Name "Windows 7" `
        -Comments "This is intended to hold language packs for Windows 7" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages\Language Packs" `
        -enable "True" `
        -Name "Windows 8.1" `
        -Comments "This is intended to hold language packs for Windows 8.1" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages\Language Packs" `
        -enable "True" `
        -Name "Windows 10" `
        -Comments "This is intended to hold language packs for Windows 10" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages" `
        -enable "True" `
        -Name "OS Patches" `
        -Comments "This is intended to hold OS Patches for all OSes" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages\OS Patches" `
        -enable "True" `
        -Name "Windows 7" `
        -Comments "This is intended to hold OS Patches for Windows 7" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages\OS Patches" `
        -enable "True" `
        -Name "Windows 8.1" `
        -Comments "This is intended to hold OS Patches for Windows 7" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Packages\OS Patches" `
        -enable "True" `
        -Name "Windows 10" `
        -Comments "This is intended to hold OS Patches for Windows 7" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Task Sequences" `
        -enable "True" `
        -Name "Windows 7" `
        -Comments "This is intended to hold the various task sequences for Windows 7 images" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Task Sequences" `
        -enable "True" `
        -Name "Windows 8.1" `
        -Comments "This is intended to hold the various task sequences for Windows 8.1 images" `
        -ItemType "folder" -Verbose

    new-item -path "DS001:\Task Sequences" `
        -enable "True" `
        -Name "Windows 10" `
        -Comments "This is intended to hold the various task sequences for Windows 10 images" `
        -ItemType "folder" -Verbose

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Creating some basic task sequences"

Import-MDTTaskSequence -path "DS001:\Task Sequences\Windows 7" `
    -Name "Windows 7 - Fully Patch OS" `
    -Template "Client.xml" `
    -Comments "This task sequence will fully patch a Windows OS" `
    -ID "Win7Update" `
    -Version "1.0" `
    -OperatingSystemPath "DS001:\Operating Systems\ISO No Updates\Windows 7 ENTERPRISE in Windows 7 x64 install.wim" `
    -FullName $RegisteredFullName `
    -OrgName $RegisteredOrgName `
    -HomePage $RegisteredHomePage `
    -AdminPassword $TaskSequenceAdminPlaintext -Verbose

Import-MDTTaskSequence -path "DS001:\Task Sequences\Windows 8.1" `
    -Name "Windows 8.1 - Fully Patch OS" `
    -Template "Client.xml" `
    -Comments "This task sequence will fully patch a Windows OS" `
    -ID "Win81Update" `
    -Version "1.0" `
    -OperatingSystemPath "DS001:\Operating Systems\ISO No Updates\Windows 8.1 Enterprise Evaluation in Windows 8.1 x64 install.wim" `
    -FullName $RegisteredFullName `
    -OrgName $RegisteredOrgName `
    -HomePage $RegisteredHomePage `
    -AdminPassword $TaskSequenceAdminPlaintext -Verbose

Import-MDTTaskSequence -path "DS001:\Task Sequences\Windows 10" `
    -Name "Windows 10 - Fully Patch OS" `
    -Template "Client.xml" `
    -Comments "This task sequence will fully patch a Windows OS" `
    -ID "Win10Update" `
    -Version "1.0" `
    -OperatingSystemPath "DS001:\Operating Systems\ISO No Updates\Windows 10 Enterprise Evaluation in Windows 10 x64 install.wim" `
    -FullName $RegisteredFullName `
    -OrgName $RegisteredOrgName `
    -HomePage $RegisteredHomePage `
    -AdminPassword $TaskSequenceAdminPlaintext -Verbose

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Adding Apply Packages step to all task sequences"

Function Enable-TaskSequenceStep
{
    [CmdletBinding()]
    param(

        [String]$TaskSequenceID,
        [String]$GroupName,
        [String]$StepName

    )

    Write-Verbose "Enabling $StepName in $GroupName of $TaskSequenceID"

    $GroupTypes = @{

        "Initialization" = 0
        "Validation" = 1
        "State Capture" = 2
        "Preinstall" = 3
        "Install" = 4
        "PostInstall" = 5
        "StateRestore" = 6

    }
    
    [String]$LogPath = Join-Path $DeploymentSharePath "Control\$TaskSequenceID\ts.xml"
    
    [xml]$TaskSequence = Get-Content $LogPath -Raw -Encoding ASCII

    $Steps = $TaskSequence.sequence.group[$GroupTypes[$GroupName]].step

    ($Steps | Where-Object {$_.Name -eq $StepName}).Disable = "false"

    $TaskSequence.Save((Join-Path $DeploymentSharePath "Control\$TaskSequenceID\ts.xml"))

}

@(

    "Win7Update",
    "Win81Update",
    "Win10Update"

) | ForEach-Object {
                Enable-TaskSequenceStep -TaskSequenceID $_ `
                    -GroupName "StateRestore" `
                    -StepName "Windows Update (Pre-Application Installation)" `
                    -Verbose

                Enable-TaskSequenceStep -TaskSequenceID $_ `
                    -GroupName "StateRestore" `
                    -StepName "Windows Update (Post-Application Installation)" `
                    -Verbose
            }


#endregion

#region Downloading Windows Updates using WSUSOfflineUpdater

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Downloading Windows 7 x64 Updates"

Start-Process -FilePath "C:\Windows\System32\cmd.exe" `
    -ArgumentList @(
        "/D", 
        "/C", 
        "$ISOPath\WSUSOfflineUpdater\wsusoffline\cmd\DownloadUpdates.cmd", 
        "w61-x64", "glb", 
        "/includedotnet", 
        "/verify", 
        "/exitonerror"
    ) `
    -Wait

Write-ProgressBar $PoshProgressBar `
    -Activity "Setting up MDT Environment" `
    -Status "Downloading Windows 8.1 x64 Updates"

Start-Process -FilePath "C:\Windows\System32\cmd.exe" `
    -ArgumentList @(
        "/D", 
        "/C", 
        "$ISOPath\WSUSOfflineUpdater\wsusoffline\cmd\DownloadUpdates.cmd", 
        "w63-x64", 
        "glb", 
        "/includedotnet", 
        "/verify", 
        "/exitonerror"
    ) `
    -Wait

Write-ProgressBar $PoshProgressBar `
    -Activity "Setting up MDT Environment" `
    -Status "Downloading Windows 10 x64 Updates"

Start-Process -FilePath "C:\Windows\System32\cmd.exe" `
    -ArgumentList @(
        "/D", 
        "/C", 
        "$ISOPath\WSUSOfflineUpdater\wsusoffline\cmd\DownloadUpdates.cmd", 
        "w100-x64", 
        "glb", 
        "/includedotnet", 
        "/verify", 
        "/exitonerror"
    ) `
    -Wait


#endregion

#region Importing Windows Update Packages to MDT

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Importing update packages into MDT"


import-mdtpackage -path "DS001:\Packages\OS Patches\Windows 7" -SourcePath "$ISOPath\WSUSOfflineUpdater\wsusoffline\client\w61-x64\glb" -Verbose

import-mdtpackage -path "DS001:\Packages\OS Patches\Windows 8.1" -SourcePath "$ISOPath\WSUSOfflineUpdater\wsusoffline\client\w63-x64\glb" -Verbose

import-mdtpackage -path "DS001:\Packages\OS Patches\Windows 10" -SourcePath "$ISOPath\WSUSOfflineUpdater\wsusoffline\client\w100-x64\glb" -Verbose

#endregion

#Removing packages that cannot be installed while offline

remove-item -path "DS001:\Packages\OS Patches\Windows 7\Package_for_KB2533552 neutral amd64 6.1.1.1" -force -verbose
remove-item -path "DS001:\Packages\OS Patches\Windows 8.1\Package_for_KB2919355 neutral amd64 6.3.1.14" -force -verbose

# Clear the derived plaintext password as soon as it is no longer needed.
$TaskSequenceAdminPlaintext = $null
