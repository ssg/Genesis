<#
.SYNOPSIS
    Setup one of SSG's Windows 10 machines.

.DESCRIPTION
    This script is currently very opinionated on where to put things
    and it can make you lose data. DO NOT RUN ON YOUR MACHINE unless you
    know what you're doing.

    To customize the behavior you can edit SampleConfig.psd1

.NOTES
    Version:        0.6 alpha
    Author:         Sedat Kapanoglu
#>

#Requires -RunAsAdministrator
#Requires -Version 5.0

param(
    [Parameter(Mandatory)]
    [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]
    [hashtable]$ConfigFile
)

$ErrorActionPreference = "Stop"

$Config = $ConfigFile
Write-Debug "Importing Lib"
Import-Module -Force (Join-Path $PSScriptRoot Lib)    # force reload

Write-Debug "Starting asserts"
Assert-Configuration "Computer name" {
    $computerName = $env:ComputerName
    if ($computerName -like 'DESKTOP-*') {
        Write-Output "not set"
        $computerName = Read-Host "Enter a computer name"
        Rename-Computer -NewName $computerName
        Write-Output "Issued rename request. Will probably take effect after restart"
        Set-RestartNeeded
    }
}

Write-Output "Setting up $env:ComputerName"

Assert-Configuration "Keyboard" {
    [void] (Assert-RegistryValue -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Type Dword `
        -Value $Config.Keyboard.Delay)
    [void] (Assert-RegistryValue -Path "HKCU:\Control Panel\Input Method" -Name "EnableHexNumPad" -Type String `
        -Value $Config.Keyboard.HexNumPad.ToString())

    # crash on Ctrl+ScrollLock handling
    [void] (Assert-RegistryValue -Path "HKLM:\System\CurrentControlSet\Services\kbdhid\Parameters" -Name "CrashOnCtrlScroll" -Type Dword `
        -Value $Config.Keyboard.HexNumPad)
    [void] (Assert-RegistryValue -Path "HKLM:\System\CurrentControlSet\Services\i8042prt\Parameters" -Name "CrashOnCtrlScroll" -Type Dword `
        -Value $Config.Keyboard.HexNumPad)
    [void] (Assert-RegistryValue -Path "HKLM:\System\CurrentControlSet\Services\hyperkbd\Parameters" -Name "CrashOnCtrlScroll" -Type Dword `
        -Value $Config.Keyboard.HexNumPad)
}

$category = $Config.Network.ActiveConnectionNetworkCategory
if ($category) {
    Assert-Configuration "Network" {
        $profile = Get-NetConnectionProfile
        if ($profile.Count -eq 0) {
            Write-Warning "no active connections found...skipping"
            return $false
        }
        if ($profile.Count -eq 1) {
            Write-Warning "multiple connections found...ambigious...skipping"
            return $false
        }
        if ($profile -and $category -and ($profile.NetworkCategory -ne $category)) {
            Write-Output "changing from $($profile.NetworkCategory) to $category"
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory $category
            return $true
        }
        Write-Output "already $($profile.NetworkCategory)..."
        return $false
    }
}

Assert-Configuration "Explorer" {
    # file extensions
    [void] (Assert-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "HideFileExt" -Type Dword -Value $Config.Explorer.ShowFileExtensions)
    # recycle bin capacity
    Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Bitbucket\Volume" `
    | ForEach-Object {
        Set-RecycleBinCapacity -Volume (Split-Path $_.Name -Leaf) -Capacity $Config.Explorer.MaxRecycleBinCapacity
    }
}

Assert-Configuration "Taskbar" {
    [void] (Assert-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "People" -Type Dword -Value $Config.TaskBar.ShowPeopleButton)
    [void] (Assert-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ShowTaskViewButton" -Type Dword -Value $Config.TaskBar.ShowTaskViewButton)
    [void] (Assert-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
        -Name "SearchboxTaskbarMode" -Type Dword -Value $Config.TaskBar.SearchboxTaskbarMode)
}

if ($Config.SpecialFolders) {
    Assert-Configuration "Special Folders" {
        Write-Output ""
        $Config.SpecialFolders.Keys | ForEach-Object {
            Assert-SpecialFolder -Name $_ -PreferredLocation $Config.SpecialFolders[$_]
        }
    }
}

Assert-Configuration "Chocolatey" {
    if (!(Test-Path -Path "$env:ProgramData\Chocolatey")) {
        # install chocolatey
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        return $true
    }
    return $false
}

Assert-Configuration "Default browser" {
    $defaultBrowser = (Get-Browser $Config.DefaultBrowser)
    $builtIn = !($defaultBrowser.LocalPath);
    if (!$builtIn -and !(Test-Path $defaultBrowser.LocalPath)) {
        Write-Output "installing..."
        & choco install $defaultBrowser.ChocolateyPackage -y
    } else {
        Write-Output "$($Config.DefaultBrowser) is already installed, checking if it's the default..."
        if (!(Test-DefaultBrowser $defaultBrowser.Tag)) {
            Write-Output "nope :("
            Write-Output "Please ensure $($defaultBrowser.Name) is the default browser - opening settings app"
            Start-Process "ms-settings:defaultapps"
            Wait-ForEnter
        }
    }
}

if ($Config.WindowsFeatures) {
    Assert-Configuration "Windows features"  {
        $Config.WindowsFeatures | ForEach-Object {
            Assert-WindowsFeature $_
        }
    }
}

Assert-Configuration "Common Microsoft Store apps" {
    [void] (Assert-StoreAppsInstalled $Config.CommonStoreApps)
}

Assert-Configuration "Desktop shortcuts" {
    $Config.DesktopUrlShortcuts.Keys | ForEach-Object {
        [void] (Assert-DesktopShortcut $_ $Config.DesktopUrlShortcuts[$_])
    }
}

### Development Environment Setup ###

if ($Config.Linux -eq 1) {
    Assert-Configuration "Windows Subsystem for Linux" {
        $feature = Get-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online
        if ($feature -and ($feature.State -eq "Disabled"))
        {
            Write-Progress "enabling..."
            Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -All `
                -LimitAccess -NoRestart
            return $true
        }
    }
}

Assert-Configuration "Developer mode" {
    return (Assert-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
        -Name AllowDevelopmentWithoutDevLicense -Type Dword -Value $Config.DeveloperMode)
}

Assert-Configuration "Windows capabilities" {
    $result = $false
    $Config.WindowsCapabilities.Keys | ForEach-Object {
        $id = $Config.WindowsCapabilities[$_]
        $result = $result -or (Assert-WindowsCapability -Name $_ -Id $id)
    }
    return $result
}

if ($Config.IgnoreKeepAwakeRequestsFromProcesses) {
    Assert-Configuration "Ignore keep awake requests" {
        $Config.IgnoreKeepAwakeRequestsFromProcesses.Keys | ForEach-Object {
            $mode = $Config.IgnoreKeepAwakeRequestsFromProcesses[$_]
            Assert-NoKeepAwake -Process $_ -Mode $mode
        }
    }
}

Assert-Configuration "Windows Defender exclusions" {
    $exclusions = $WindowsDefender.ExclusionPaths
    foreach ($path in $exclusions) {
        Add-MpPreference -ExclusionPath $path
    }
    return !!$exclusions
}

Assert-Configuration "Development related Microsoft Store apps" {
    [void] (Assert-StoreAppsInstalled $Config.DevStoreApps)
}

if ($Config.ChocolateyPackages) {
    Assert-Configuration "Chocolatey packages" {
        return Assert-ChocolateyPackages $Config.ChocolateyPackages
    }
}

### End of Configuration ###

Write-Output "Well, that's been a pleasure!"
if (Get-RestartNeeded) {
    Write-Output "Please restart the computer to ensure changes take effect"
}
