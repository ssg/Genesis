<#
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
        Tag = "AppXq0fevzme2pys62n3e0fbqa7peapykr8v"
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
    return $Browsers[$Name]
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
    if (!(Test-Path $PreferredLocation)) {
        Write-Output "Creating new $Name folder at: $PreferredLocation"
        mkdir $PreferredLocation
    }
    $regName = $SpecialFolders[$Name]
    Write-Progress "  $Name..."
    [void] (Assert-SpecialFolderPath -Name $regName -FolderPath $PreferredLocation)
}

function Assert-NoKeepAwake {
    param(
        $Process,
        $Mode
    )
    # it's harmless to redo this configuration each time so we don't
    # necessarily check for existing config values
    & powercfg /requestsoverride PROCESS $Process $Mode
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
        return $false
    }
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force
    }
    $prop = (Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction SilentlyContinue)
    if ($prop -ne $Value) {
        Write-Progress "updating..."
        Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value
        return $true
    }
    return $false
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
    if ($Apps -eq $null) {
        Write-Warning "Store apps config not found"
        return $false
    }
    foreach ($name in $Apps.Keys) {
        Write-Progress "  $name..."
        $item = (Get-AppxPackage | Where-Object { $_.Name -eq $name })
        if ($null -eq $item) {
            $productId = $Apps[$name]
            Write-Output "needs to be installed"
            Start-Process "https://www.microsoft.com/store/productId/$productId"
        } else {
            Write-Output "OK"
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
        return $true
    }
    Write-Progress "nice..."
    return $false
}

function Assert-ChocolateyPackages {
    param(
        [string[]]$Packages
    )
    $result = $false
    $list = choco list --id-only --local-only --limit-output
    [System.Collections.Generic.HashSet[string]]$installedPackages = $list
    foreach ($name in $Packages) {
        Write-Progress $name
        if ($installedPackages -notcontains $name) {
            Write-Progress -Status "installing"
            & choco install $Name -y
            $result = $true
        }
    }
    return $result
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
        return $true
    }
    return $false
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
        return $true
    }
    return $false
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
    Write-Progress $Name
    if (& $Script) {
        Write-Output "restart needed..."
    }
}

function Set-RecycleBinCapacity {
    param(
        $Volume,
        $Capacity
    )
    [void] (Assert-RegistryValue `
        -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Bitbucket\Volume\$Volume" `
        -Name MaxCapacity -Type Dword -Value $Capacity)
}

function Get-DesktopPath {
    return [Environment]::GetFolderPath("Desktop")
}

function Wait-ForEnter {
    Write-Output "Press ENTER to continue..."
    Read-Host | Out-Null
}
