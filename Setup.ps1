<#
.SYNOPSIS
    Setup one of SSG's Windows 10 machines.

.DESCRIPTION
    This script is currently very opinionated on where to put things
    and it can make you lose data. DO NOT RUN ON YOUR MACHINE unless you
    know what you're doing.

    To customize the behavior you can edit Config.psd1

.NOTES
    Version:        0.4 alpha
    Author:         Sedat Kapanoglu
#>

#Requires -RunAsAdministrator
#Requires -Version 5.0

param(
    [switch]$Force = $false
)

if (!$Force) {
    Write-Warning "This script is dangerous and can destroy data on your computer"
    Write-Warning "Please do not run unless you know what you're doing"
    Write-Warning "It's a good idea to check out Config.psd1 first"
    Write-Warning "Use -Force parameter in order to run it"
    break
}

$Config = Import-PowerShellDataFile Config.psd1
Import-Module -Force (Join-Path $PSScriptRoot Lib)    # force reload

$ErrorActionPreference = "Stop"

Assert-Configuration "Computer name" {
    $computerName = $env:ComputerName
    if ($computerName -like 'DESKTOP-*') {
        Write-Host "not set"
        $computerName = Read-Host "Enter computer name"
        Rename-Computer -NewName $computerName
        Write-Output "Issued rename request. Will probably take effect after restart"
        Set-RestartNeeded
    }
}

Write-Output "Setting up $env:ComputerName"

Assert-Configuration "Recycle Bin capacity on all drives" {
    Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Bitbucket\Volume" `
    | ForEach-Object {
        Set-RecycleBinCapacity -Volume (Split-Path $_.Name -Leaf) -Capacity $Config.MaxRecycleBinCapacity
    }
}

Assert-Configuration "Keyboard delay" {
    [void] (Assert-RegistryValue -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Type Dword `
        -Value $Config.KeyboardDelay)
}

Assert-Configuration "Hex NumPad" {
    [void] (Assert-RegistryValue -Path "HKCU:\Control Panel\Input Method" -Name "EnableHexNumPad" -Type String `
        -Value $Config.EnableHexNumPad.ToString())

}

Assert-Configuration "Taskbar buttons" {
    [void] (Assert-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "People" -Type Dword -Value $Config.TaskBar.ShowPeopleButton)
    [void] (Assert-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ShowTaskViewButton" -Type Dword -Value $Config.TaskBar.ShowTaskViewButton)
    [void] (Assert-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
        -Name "SearchboxTaskbarMode" -Type Dword -Value $Config.TaskBar.SearchboxTaskbarMode)
}

# Secondary drive

$Config.SpecialFolders.Keys | ForEach-Object {
    $folder = $Config.SpecialFolders[$_]
    Assert-SpecialFolder -Name $_ -RegName $folder.RegName -PreferredLocation $folder.PreferredLocation
}

Assert-Configuration "Default browser" {
    $defaultBrowser = (Get-Browser $Config.DefaultBrowser)
    if (!(Test-Path $defaultBrowser.LocalPath)) {
        Start-Process $defaultBrowser.DownloadUrl
    } else {
        Write-SameLine "$($Config.DefaultBrowser) already installed, checking if default..."
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
            Write-SameLine "enabling..."
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

Assert-Configuration "Development related Microsoft Store apps" {
    [void] (Assert-StoreAppsInstalled $Config.DevStoreApps)
}

if ($Config.ChocolateyPackages) {
    Assert-Configuration "Chocolatey" {
        if (!(Test-Path -Path "$env:ProgramData\Chocolatey")) {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            return $true
        }
        return $false
    }
    Assert-Configuration "Chocolatey package provider" {
        if (!(Get-PackageProvider "chocolatey" -ErrorAction SilentlyContinue)) {
            $provider = Install-PackageProvider "chocolatey" -Force
            return $true
        }
        return $false
    }
    Assert-Configuration "Chocolatey packages" {
        $result = $false
        $Config.ChocolateyPackages | ForEach-Object {
            $result = $result -or (Assert-ChocolateyPackage $_)
        }
    }
}

### End of Configuration ###

Write-Host "Well that's been a pleasure!"
if (Get-RestartNeeded) {
    Write-Host "Please restart the computer to ensure changes take effect"
}
