<#
Configuration module - feel free to edit this one to customize behavior
#>

@{
    MaxRecycleBinCapacity = 1024 # MB - applies to all drives on the system
    KeyboardDelay = 0
    EnableHexNumPad = 1 # enables Alt-+ method for inputting hex Unicode values 1 = enabled, 0 = disabled
    TaskBar = @{
        ShowPeopleButton = 0
        ShowTaskViewButton = 0
        SearchboxTaskbarMode = 1 # 1 = Search box as a button
    }
    SpecialFolders = @{
        Downloads = @{
            RegName = "{374DE290-123F-4565-9164-39C4925E467B}"
            PreferredLocation = "D:\down"
        }
    }
    IgnoreKeepAwakeRequestsFromProcesses = @{
        "chrome.exe" = "EXECUTION" # forgetting chrome open would prevent machine from going to sleep
    }
    DefaultBrowser = "Chrome" # defined browsers are in Lib.psm1
    DesktopUrlShortcuts = @{
        "Radio Paradise.m3u" = "https://www.radioparadise.com/m3u/aac-320.m3u"
        "SceneSat.m3u" = "https://scenesat.com/listen/normal/hi.m3u"
        "Groove Salad.pls" = "http://somafm.com/groovesalad130.pls"
    }
    ChocolateyPackages = @(
        "notepad2"
        "7zip"
        "vlc"
        "git"
        "openvpn"
        "tortoisehg"
        "sql-server-management-studio"
    )
    WindowsFeatures = @(
        "NetFx3" # required for Saitek X-55 drivers
    )
    CommonStoreApps = @{
        "dotPDNLLC.paint.net" = "9NBHCS1LX4R0"
        "5319275A.WhatsAppDesktop" = "9NKSQGP7F2NH"
        "TelegramMessengerLLP.TelegramDesktop" = "9NZTWSQNTD0S"
        "SpotifyAB.SpotifyMusic" = "9NCBCSZSJRSB"
    }
    DeveloperMode = 1
    Linux = 1
    DevStoreApps = @{
        "91750D7E.Slack" = "9WZDNCRDK3WP"
        "CanonicalGroupLimited.UbuntuonWindows" = "9NBLGGH4MSV6"
        "Microsoft.WinDbg" = "9PGJGD53TN86"
    }
    WindowsCapabilities = @{
        OpenSSH = "OpenSSH.Client~~~~0.0.1.0"
    }
}