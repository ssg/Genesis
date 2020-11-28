#Requires -RunAsAdministrator
#Requires -Version 5.0
#Requires -Modules FXPSYaml

# We want to handle errors explicitly.
$ErrorActionPreference = "Stop"

function Update-SystemConfiguration {
<#
.SYNOPSIS
    Updates the system configuration and installs the required applications
    by processing a Genesis configuration file.

.DESCRIPTION
    This script is currently very opinionated on where to put things
    and it can make you lose data. DO NOT RUN ON YOUR MACHINE unless you
    know what you're doing.

    To customize the behavior you can edit SampleConfig.yaml

.NOTES
    Author:         Sedat Kapanoglu
#>
    [CmdletBinding()]
    param(
        # YAML Configuration file to use for setup.
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -PathType Leaf $_ })]
        [System.IO.FileInfo]$ConfigFile,

        # Set computer name, otherwise you get prompted
        # for a new name if it's a random Windows 10 PC name
        # such as DESKTOP-ABC123.
        [string]$ComputerName
    )

    Write-Debug "Reading configuration file $ConfigFile"
    $Config = ConvertFrom-Yaml -Path $ConfigFile

    if ($null -eq $Config) {
        throw "Configuration file $ConfigFile cannot be loaded"
    }

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

    Write-Output "Working on $env:ComputerName"

    Assert-Configuration "Keyboard" {
        [void] (Assert-RegistryValue -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Type Dword `
                -Value $Config.Keyboard.Delay)
        [void] (Assert-RegistryValue -Path "HKCU:\Control Panel\Input Method" -Name "EnableHexNumPad" -Type String `
                -Value $Config.Keyboard.HexNumPad.ToString())

        # crash on Ctrl+ScrollLock handling
        $prefix = "HKLM:\System\CurrentControlSet\Services"
        [void] (Assert-RegistryValue -Path "$prefix\kbdhid\Parameters" -Name "CrashOnCtrlScroll" -Type Dword `
                -Value $Config.Keyboard.CrashOnCtrlScroll)
        [void] (Assert-RegistryValue -Path "$prefix\i8042prt\Parameters" -Name "CrashOnCtrlScroll" -Type Dword `
                -Value $Config.Keyboard.CrashOnCtrlScroll)
        [void] (Assert-RegistryValue -Path "$prefix\hyperkbd\Parameters" -Name "CrashOnCtrlScroll" -Type Dword `
                -Value $Config.Keyboard.CrashOnCtrlScroll)
    }

    $category = $Config.Network.ActiveConnectionNetworkCategory
    if ($category) {
        Assert-Configuration "Network" {
            $profileName = Get-NetConnectionProfile
            if ($profileName.Count -eq 0) {
                Write-Warning "no active connections found...skipping"
                return
            }
            if ($profileName.Count -eq 1) {
                Write-Warning "multiple connections found...ambigious...skipping"
                return
            }
            if ($profileName -and $category -and ($profileName.NetworkCategory -ne $category)) {
                Write-Output "changing from $($profileName.NetworkCategory) to $category"
                Set-NetConnectionProfile -InterfaceIndex $profileName.InterfaceIndex -NetworkCategory $category
                return
            }
            Write-Output "already $($profileName.NetworkCategory)..."
        }
    }

    Assert-Configuration "Explorer" {
        # file extensions
        Assert-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
                -Name "HideFileExt" -Type Dword -Value $Config.Explorer.ShowFileExtensions
        # recycle bin capacity
        Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Bitbucket\Volume" `
        | ForEach-Object {
            Set-RecycleBinCapacity -Volume (Split-Path $_.Name -Leaf) -Capacity $Config.Explorer.MaxRecycleBinCapacity
        }
    }

    Assert-Configuration "Taskbar" {
        Assert-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
                -Name "People" -Type Dword -Value $Config.TaskBar.ShowPeopleButton
        Assert-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
                -Name "ShowTaskViewButton" -Type Dword -Value $Config.TaskBar.ShowTaskViewButton
        Assert-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
                -Name "SearchboxTaskbarMode" -Type Dword -Value $Config.TaskBar.SearchboxTaskbarMode
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
        }
    }

    Assert-Configuration "Default browser" {
        $browser = $Config.DefaultBrowser
        Write-Debug "Checking if default browser is $browser"
        $defaultBrowser = (Get-Browser $Config.DefaultBrowser)
        $builtIn = !($defaultBrowser.LocalPath);
        if (!$builtIn -and !(Test-Path $defaultBrowser.LocalPath)) {
            Write-Output "installing external $browser..."
            & choco install $defaultBrowser.ChocolateyPackage -y
        }
        else {
            Write-Output "$browser is already installed"
            if (-not (Test-DefaultBrowser $defaultBrowser.Tag)) {
                Write-Output "Please ensure $browser is the default browser - opening settings app"
                Start-Process "ms-settings:defaultapps"
            }
        }
    }

    if ($Config.WindowsFeatures) {
        Assert-Configuration "Windows features" {
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
            if ($feature -and ($feature.State -eq "Disabled")) {
                Write-Progress "enabling..."
                Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -All `
                    -LimitAccess -NoRestart
            }
        }
    }

    Assert-Configuration "Developer mode" {
        Assert-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
                -Name AllowDevelopmentWithoutDevLicense -Type Dword -Value $Config.DeveloperMode
    }

    Assert-Configuration "Windows capabilities" {
        $Config.WindowsCapabilities.Keys | ForEach-Object {
            $id = $Config.WindowsCapabilities[$_]
            Assert-WindowsCapability -Name $_ -Id $id
        }
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
    }

    Assert-Configuration "Development related Microsoft Store apps" {
        Assert-StoreAppsInstalled $Config.DevStoreApps
    }

    if ($Config.ChocolateyPackages) {
        Assert-Configuration "Chocolatey packages" {
            Assert-ChocolateyPackages $Config.ChocolateyPackages
        }
    }

    ### End of Configuration ###

    Write-Output "Well, that's been a pleasure!"
    if (Get-RestartNeeded) {
        Write-Output "Please restart the computer to ensure changes take effect"
    }
}