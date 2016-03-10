$ISOPath = "C:\My\DSCTesting\MDTISOs"

$InstalledModules = Get-Module -ListAvailable

if(!($InstalledModules | where {$_.Name -match "PoshProgressBar"}))
{
    Install-Module PoshProgressBar -Verbose
}

(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/Tiberriver256/Tiberriver256.GitHub.io/master/favicon.ico", "$ISOPath\favicon.ico")

$PoshProgressBar = New-ProgressBar -MaterialDesign -Theme Dark -IsIndeterminate $True -Type Circle -IconPath "$ISOPath\favicon.ico" -Size Medium

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Installing xPSDesiredStateConfiguration"

if(!($InstalledModules | where {$_.Name -match "xPSDesiredStateConfiguration"}))
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
        URI = "http://care.dlservice.microsoft.com/dl/download/evalx/win7/x64/EN/7600.16385.090713-1255_x64fre_enterprise_en-us_EVAL_Eval_Enterprise-GRMCENXEVAL_EN_DVD.iso"
        DestinationPath = "$ISOPath\Win7EnterpriseTrialx64.iso"
        MatchSource = $False
    }

    xRemoteFile Win81EnterPriseISO
    {
        URI = "http://download.microsoft.com/download/B/9/9/B999286E-0A47-406D-8B3D-5B5AD7373A4A/9600.16384.WINBLUE_RTM.130821-1623_X64FRE_ENTERPRISE_EVAL_EN-US-IRM_CENA_X64FREE_EN-US_DV5.ISO"
        DestinationPath = "$ISOPath\Win81EnterpriseTrialx64.iso"
        MatchSource = $False
    }

    xRemoteFile Win10EnterPriseISO
    {
        URI = "http://care.dlservice.microsoft.com/dl/download/C/3/9/C399EEA8-135D-4207-92C9-6AAB3259F6EF/10240.16384.150709-1700.TH1_CLIENTENTERPRISEEVAL_OEMRET_X64FRE_EN-US.ISO"
        DestinationPath = "$ISOPath\Win10EnterpriseTrialx64.iso"
        MatchSource = $False
    }

  } 
}

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Starting DSC Config to download and install MDT and toolset"
DeployMDT2013Lab -Servers localhost -OutputPath $ISOPath -ISOPath $ISOPath

Start-DscConfiguration -Path $ISOPath -wait -Verbose -Force

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Installing IMDisk for mounting ISOs"
if( ! (Test-Path C:\Windows\System32\imdisk.exe) )
{

    Start-Process -FilePath $ISOPath\imdiskinst.exe -ArgumentList "-y" -Wait

}

Write-ProgressBar $PoshProgressBar -Activity "Setting up MDT Environment" -Status "Creating deployment share at C:\DeploymentShare"

#region Extracting ISOs and importing into MDT

New-Item -Path "C:\DeploymentShare" -ItemType directory
New-SmbShare -Name "DeploymentShare$" -Path "C:\DeploymentShare" -FullAccess Administrators
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
new-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "C:\DeploymentShare" -Description "MDT Deployment Share" -NetworkPath "\\NAHOLLLO39872N\DeploymentShare$" -Verbose | add-MDTPersistentDrive -Verbose
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

'@ | Out-File C:\DeploymentShare\Control\CustomSettings.ini -Encoding ASCII

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
    -FullName "Tiberriver256" `
    -OrgName "Tiberriver256.GitHub.IO" `
    -HomePage "http://www.google.com" `
    -AdminPassword "Imaging123" -Verbose

Import-MDTTaskSequence -path "DS001:\Task Sequences\Windows 8.1" `
    -Name "Windows 8.1 - Fully Patch OS" `
    -Template "Client.xml" `
    -Comments "This task sequence will fully patch a Windows OS" `
    -ID "Win81Update" `
    -Version "1.0" `
    -OperatingSystemPath "DS001:\Operating Systems\ISO No Updates\Windows 8.1 Enterprise Evaluation in Windows 8.1 x64 install.wim" `
    -FullName "Tiberriver256" `
    -OrgName "Tiberriver256.GitHub.IO" `
    -HomePage "http://www.google.com" `
    -AdminPassword "Imaging123" -Verbose

Import-MDTTaskSequence -path "DS001:\Task Sequences\Windows 10" `
    -Name "Windows 10 - Fully Patch OS" `
    -Template "Client.xml" `
    -Comments "This task sequence will fully patch a Windows OS" `
    -ID "Win10Update" `
    -Version "1.0" `
    -OperatingSystemPath "DS001:\Operating Systems\ISO No Updates\Windows 10 Enterprise Evaluation in Windows 10 x64 install.wim" `
    -FullName "Tiberriver256" `
    -OrgName "Tiberriver256.GitHub.IO" `
    -HomePage "http://www.google.com" `
    -AdminPassword "Imaging123" -Verbose

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
    
    [String]$LogPath = "C:\DeploymentShare\Control\$TaskSequenceID\ts.xml"
    
    [xml]$TaskSequence = Get-Content $LogPath -Raw -Encoding ASCII

    $Steps = $TaskSequence.sequence.group[$GroupTypes[$GroupName]].step

    ($Steps | where {$_.Name -eq $StepName}).Disable = "false"

    $TaskSequence.Save("C:\DeploymentShare\Control\$TaskSequenceID\ts.xml")

}

@(

    "Win7Update",
    "Win81Update",
    "Win10Update"

) | foreach {
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
