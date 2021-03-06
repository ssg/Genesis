﻿<#
This module contains library cmdlets for Genesis
#>

$script:RestartNeeded = $false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Browsers = @{
    "Chrome" = @{
        LocalPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
        ChocolateyPackage = "googlechrome"
        Tag = "ChromeHTML"
    }
    "Firefox" = @{
        LocalPath = "C:\Program Files\Mozilla Firefox\firefox.exe"
        ChocolateyPackage = "firefox"
        Tag = "FirefoxURL"
    }
    "Edge" = @{
        Tag = "MSEdgeHTM"
    }
    "InternetExplorer" = @{
        Tag = "IE.HTTP"
    }
}

$SpecialFolders = @{
    "Desktop" = "{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"
    "Documents" = "{FDD39AD0-238F-46AF-ADB4-6C85480369C7}"
    "Downloads" = "{374DE290-123F-4565-9164-39C4925E467B}"
    "Favorites" = "{1777F761-68AD-4D8A-87BD-30B759FA33DD}"
    "ProgramData" = "{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97}"
}

function Get-Browser {
    param(
        $Name
    )
    $browser = $Browsers[$Name]
    if ($browser -eq $null) {
        throw "Invalid browser name: $Name"
    }
    return $browser
}

function Set-RestartNeeded {
    $script:RestartNeeded = $true
}

function Get-RestartNeeded {
    return $script:RestartNeeded
}

function Assert-SpecialFolder {
    param(
        $Name,
        $PreferredLocation
    )
    Write-Debug "Checking special folder $Name for $PreferredLocation"
    if (!(Test-Path $PreferredLocation)) {
        Write-Output "Creating new $Name folder at: $PreferredLocation"
        mkdir $PreferredLocation
    }
    $regName = $SpecialFolders[$Name]
    Write-Progress "  $Name..."
    Assert-SpecialFolderPath -Name $regName -FolderPath $PreferredLocation
}

function Assert-NoKeepAwake {
    param(
        $Process,
        $Mode
    )
    $args = @("/requestsoverride", "PROCESS", $Process, $Mode)
    Write-Debug "Running powercfg $args"
    # it's harmless to redo this configuration each time so we don't
    # necessarily check for existing config values
    & powercfg $args
}

function Assert-RegistryValue {
    param(
        $Path,
        $Name,
        $Type,
        $Value
    )
    if ($null -eq $Value) {
        # skip this if relevant configuration information is missing
        # therefore the function is called unnecessarily
        Write-Warning "Missing configuration option for registry $Path\$Name"
        return
    }
    Write-Debug "Checking registry path $Path"
    if (!(Test-Path $Path)) {
        Write-Debug "Creating registry path $Path"
        New-Item -Path $Path -Force
    }
    try {
        Write-Debug "Getting registry property $Name from $Path"
        $prop = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Name)
    } catch {
        Write-Debug "Error getting registry property $Name from $Path"
        $prop = $null
    }
    if ($prop -ne $Value) {
        Write-Progress "updating..."
        Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value
    }
}

function Assert-SpecialFolderPath {
    param(
        $Name,
        $FolderPath
    )
    return (Assert-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" `
        -Name $Name -Type ExpandString -Value $FolderPath)
}

function Assert-StoreAppsInstalled {
    param(
        $Apps
    )
    if ($null -eq $Apps) {
        Write-Warning "Store apps config not found"
        return
    }
    foreach ($name in $Apps.Keys) {
        Write-Progress "  $name..."
        $item = (Get-AppxPackage | Where-Object { $_.Name -eq $name })
        if ($null -eq $item) {
            $productId = $Apps[$name]
            Start-Process "https://www.microsoft.com/store/productId/$productId"
        }
    }
}

function Assert-DesktopShortcut {
    param(
        $Name,
        $Url
    )
    $desktop = Get-DesktopPath
    $filename = (Join-Path $desktop $Name)
    if (!(Test-Path $filename)) {
        Write-Progress "downloading..."
        Invoke-WebRequest -Uri $Url -OutFile $filename
    }
    Write-Progress "nice..."
}

function Assert-ChocolateyPackages {
    param(
        [string[]]$Packages
    )
    $list = choco list --id-only --local-only --limit-output
    [System.Collections.Generic.HashSet[string]]$installedPackages = $list
    foreach ($name in $Packages) {
        Write-Progress "$name..."
        if ($installedPackages -notcontains $name) {
            Write-Progress "installing"
            & choco install $Name -y
        }
    }
}

function Assert-WindowsFeature {
    param(
        $Name
    )
    $feature = Get-WindowsOptionalFeature -FeatureName $Name -Online
    if ($feature -and ($feature.State -eq "Disabled"))
    {
        Write-Progress "enabling $Name..."
        Enable-WindowsOptionalFeature -FeatureName $Name -Online -All -NoRestart
    }
}

function Assert-WindowsCapability {
    param(
        $Name,
        $Id
    )
    $state = (Get-WindowsCapability -Online -Name $Id).State
    if ($state -ne 'Installed') {
        Write-Progress "installing $Name..."
        Add-WindowsCapability -Online -Name $Id
    }
}

function Test-DefaultBrowser {
    param (
        $Tag
    )
    return (Get-ItemPropertyValue `
        "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" ProgId) `
        -like "$Tag*"
}

function Assert-Configuration {
    param (
        $Name,
        $Script
    )
    Write-Debug "Setting up $Name"
    Write-Progress $Name
    & $Script
}

function Set-RecycleBinCapacity {
    param(
        $Volume,
        $Capacity
    )
    Assert-RegistryValue `
        -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Bitbucket\Volume\$Volume" `
        -Name MaxCapacity -Type Dword -Value $Capacity
}

function Get-DesktopPath {
    return [Environment]::GetFolderPath("Desktop")
}
