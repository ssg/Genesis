<#
This module contains library cmdlets for Genesis
#>

$script:RestartNeeded = $false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Browsers = @{
    "Chrome" = @{
        LocalPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
        DownloadUrl = "https://www.google.com/chrome/"
        Tag = "ChromeHTML"
    }
    "Firefox" = @{
        LocalPath = "C:\Program Files\Mozilla Firefox\firefox.exe"
        DownloadUrl = "https://www.mozilla.org/en-US/firefox/new/"
        Tag = "FirefoxURL"
    }
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
        $RegName,
        $PreferredLocation
    )
    if (!(Test-Path $PreferredLocation)) {
        Write-Output "Creating new $Name folder at: $PreferredLocation"
        mkdir $PreferredLocation
    }
    Assert-Configuration "$Name folder location" {
        [void] (Assert-SpecialFolderPath -Name $RegName -FolderPath $PreferredLocation)
    }
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
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force
    }
    $prop = (Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction SilentlyContinue)
    if ($prop -ne $Value) {
        Write-Host -NoNewLine "updating..."
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
    Write-Host ""
    $Apps.Keys | ForEach-Object {
        $name = $_
        Write-Host -NoNewLine "  $name..."
        $item = (Get-AppxPackage | Where-Object { $_.Name -eq $name })
        if ($null -eq $item) {
            $productId = $Apps[$_]
            Write-Host "needs to be installed"
            Start-Process "https://www.microsoft.com/store/productId/$productId"
        } else {
            Write-Host "OK"
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
        Write-Host -NoNewLine "downloading..."
        Invoke-WebRequest -Uri $Url -OutFile $filename
        return $true
    }
    Write-Host -NoNewLine "nice..."
    return $false
}

function Assert-ChocolateyPackage {
    param(
        $Name
    )
    Write-Host -NoNewLine "  $Name..."
    if (choco list --id-only --local-only --limit-output --exact $Name | Where-Object { $_ -eq $Name }) {
        Write-Host "OK"
        return $false
    }
    Write-Host -NoNewLine "installing..."
    Install-Package -ProviderName chocolatey -Name $Name -Force
    Write-Host "OK"
    return $true
}

function Assert-WindowsFeature {
    param(
        $Name
    )
    $feature = Get-WindowsOptionalFeature -FeatureName $Name -Online
    if ($feature -and ($feature.State -eq "Disabled"))
    {
        Write-SameLine "enabling $Name..."
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
        Write-Host -NoNewline "installing $Name..."
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
    Write-Host -NoNewLine "Checking $Name..."
    if (& $Script) {
        Write-Host -NoNewline "restart needed..."
    }
    Write-Host "OK"
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
    Write-Host -NoNewLine "Press ENTER to continue..."
    Read-Host | Out-Null
}

function Write-SameLine {
    param(
        $Message
    )
    Write-Host -NoNewline $Message
}

