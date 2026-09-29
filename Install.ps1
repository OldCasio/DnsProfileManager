# DNS Profile Manager - Installer (Windows 10/11, PowerShell 5.1)
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppName   = "DNS Profile Manager"
$AppKey    = "DnsProfileManager"
$Version   = "1.1.0"
$Publisher = "DNS Profile Manager"

function Msg($text, $title, $buttons = "OK", $icon = "Information") {
    return [Windows.Forms.MessageBox]::Show($text, $title, $buttons, $icon)
}

# Elevate
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

try {
    $src = Join-Path $PSScriptRoot "app"
    if (-not (Test-Path (Join-Path $src "DnsProfileManager.ps1"))) {
        throw "The 'app' folder was not found next to Install.ps1. Extract the whole ZIP first."
    }

    $answer = Msg "Install $AppName on this computer?" "$AppName Setup" "YesNo" "Question"
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { exit }

    $installDir = Join-Path $env:ProgramFiles $AppName
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Copy-Item -Path (Join-Path $src "*") -Destination $installDir -Recurse -Force
    Copy-Item -Path (Join-Path $PSScriptRoot "Uninstall.ps1") -Destination $installDir -Force
    Get-ChildItem $installDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

    $launcher = Join-Path $installDir "Launch.vbs"
    $icon     = Join-Path $installDir "DnsProfileManager.ico"

    function New-AppShortcut($path) {
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($path)
        $lnk.TargetPath       = Join-Path $env:WINDIR "System32\wscript.exe"
        $lnk.Arguments        = "`"$launcher`""
        $lnk.WorkingDirectory = $installDir
        $lnk.IconLocation     = "$icon,0"
        $lnk.Description      = "Switch DNS profiles with one click"
        $lnk.Save()
    }
    New-AppShortcut (Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "$AppName.lnk")
    New-AppShortcut (Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "$AppName.lnk")

    # Register in Settings > Apps
    $reg = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppKey"
    New-Item -Path $reg -Force | Out-Null
    $uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\Uninstall.ps1`""
    $sizeKB = [int]((Get-ChildItem $installDir -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
    Set-ItemProperty $reg DisplayName     $AppName
    Set-ItemProperty $reg DisplayVersion  $Version
    Set-ItemProperty $reg Publisher       $Publisher
    Set-ItemProperty $reg InstallLocation $installDir
    Set-ItemProperty $reg DisplayIcon     $icon
    Set-ItemProperty $reg UninstallString $uninstallCmd
    New-ItemProperty $reg NoModify -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty $reg NoRepair -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty $reg EstimatedSize -Value $sizeKB -PropertyType DWord -Force | Out-Null

    $launch = Msg "$AppName was installed successfully.`r`n`r`nA shortcut was added to the Desktop and Start menu.`r`n`r`nLaunch it now?" "$AppName Setup" "YesNo" "Information"
    if ($launch -eq [Windows.Forms.DialogResult]::Yes) {
        Start-Process (Join-Path $env:WINDIR "System32\wscript.exe") -ArgumentList "`"$launcher`""
    }
} catch {
    Msg "Installation failed:`r`n$($_.Exception.Message)" "$AppName Setup" "OK" "Error" | Out-Null
}
