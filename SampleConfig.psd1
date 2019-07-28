<#
Sample Configuration - feel free to edit this one to customize behavior
The format is a PowerShell object but boolean values are denoted with 0 = false, 1 = true
#>

@{
    Keyboard = @{
        Delay = 0           # min delay - maps to KeyboardDelay registry value
        HexNumPad = 1       # enables Alt-+ method for inputting hex Unicode values 1 = enabled, 0 = disabled
    }

    Explorer = @{
        ShowFileExtensions = 1 # changes the HideFileExt registry entry
        MaxRecycleBinCapacity = 1024 # MB - applies to all drives on the system
    }

    TaskBar = @{
        ShowPeopleButton = 0
        ShowTaskViewButton = 0
        SearchboxTaskbarMode = 1 # 0 = hidden, 1 = button, 2 = big box
    }

    Network = @{
        ActiveConnectionNetworkCategory = "Private" # Public/Private
    }

    # supported keys are: Downloads, Desktop, Documents, Favorites, ProgramData
    SpecialFolders = @{
        Downloads = "D:\down"
    }

    # supported values are "Chrome", "Firefox", "Edge" or "IE"
    # if browser is not installed - it will be installed.
    # if it's not default, relevant settings page is opened
    DefaultBrowser = "Chrome"

    IgnoreKeepAwakeRequestsFromProcesses = @{
        "chrome.exe" = "EXECUTION" # forgetting chrome open would prevent machine from going to sleep
    }

    DesktopUrlShortcuts = @{
        "Radio Paradise.m3u" = "https://www.radioparadise.com/m3u/aac-320.m3u"
        "SceneSat.m3u" = "https://scenesat.com/listen/normal/hi.m3u"
        "Groove Salad.pls" = "http://somafm.com/groovesalad130.pls"
    }

    ChocolateyPackages = @(
        "notepad2"
        "7zip"
    )

    CachedCredentials = @(
        @{
            Type = "Generic"
            Name = "some.generic.credential"
            User = "username"
        },
        @{
            Type = "Domain"
            Name = "some.domain.credential"
            User = "username"
        }
    )

    # You can find out the names of all supported Windows features by running the
    # PowerShell command:
    # Get-WindowsOptionalFeature -Online | Select FeatureName | Sort FeatureName
    WindowsFeatures = @(
        "NetFx3"                # required for Saitek X-55 drivers
    )

    # format is "AppName = StoreID"
    # you can find out the appstore app names for installed apps by running
    # "Get-AppxPackage | Select Name" command
    #. StoreID is at https://www.microsoft.com/store/apps/<StoreID>
    # we open up web pages because the native Microsoft Store app doesn't support
    # multiple tabs so they would unnecessarily override each other.
    CommonStoreApps = @{
        "dotPDNLLC.paint.net" = "9NBHCS1LX4R0"
        "SpotifyAB.SpotifyMusic" = "9NCBCSZSJRSB"
    }

    # enable developer features on Windows
    DeveloperMode = 1

    # enable Windows for Linux Subsystem
    Linux = 1

    # DevStoreApps are guaranteed to be checked after developer mode is enabled
    # format is the same as CommonStoreApps
    DevStoreApps = @{
        "91750D7E.Slack" = "9WZDNCRDK3WP"
        "CanonicalGroupLimited.UbuntuonWindows" = "9NBLGGH4MSV6" # requires Linux = 1 above
    }

    WindowsCapabilities = @{
        OpenSSH = "OpenSSH.Client~~~~0.0.1.0"
    }
}