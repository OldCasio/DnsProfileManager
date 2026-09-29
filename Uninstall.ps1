# DNS Profile Manager - Uninstaller
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppName = "DNS Profile Manager"
$AppKey  = "DnsProfileManager"

function Msg($text, $title, $buttons = "OK", $icon = "Information") {
    return [Windows.Forms.MessageBox]::Show($text, $title, $buttons, $icon)
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

try {
    $installDir = $PSScriptRoot
    $answer = Msg "Remove $AppName from this computer?" "$AppName Uninstall" "YesNo" "Question"
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { exit }

    Remove-Item (Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "$AppName.lnk") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "$AppName.lnk") -Force -ErrorAction SilentlyContinue
    Remove-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppKey" -Recurse -Force -ErrorAction SilentlyContinue

    $data = Join-Path $env:APPDATA "DnsProfileManager"
    if (Test-Path $data) {
        $del = Msg "Also delete your saved DNS profiles?" "$AppName Uninstall" "YesNo" "Question"
        if ($del -eq [Windows.Forms.DialogResult]::Yes) { Remove-Item $data -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # This script lives inside the install folder, so delete the folder from a helper process after we exit.
    Set-Location $env:WINDIR
    Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"$installDir`""
    Msg "$AppName was removed." "$AppName Uninstall" | Out-Null
} catch {
    Msg "Uninstall failed:`r`n$($_.Exception.Message)" "$AppName Uninstall" "OK" "Error" | Out-Null
}
