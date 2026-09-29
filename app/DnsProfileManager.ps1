# DNS Profile Manager - Windows PowerShell 5.1 / Windows 10-11
# Right-click > Run with PowerShell. The script requests Administrator permission.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Relaunch elevated when needed
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argsList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $argsList -Verb RunAs
    exit
}

$storeDir = Join-Path $env:APPDATA "DnsProfileManager"
$storeFile = Join-Path $storeDir "profiles.json"
New-Item -ItemType Directory -Path $storeDir -Force | Out-Null
$profiles = @()
if (Test-Path $storeFile) {
    try {
        $loaded = Get-Content -Raw -Path $storeFile | ConvertFrom-Json
        if ($null -ne $loaded) { $profiles = @($loaded) }
    } catch { $profiles = @() }
}
function Save-Profiles {
    $profiles | ConvertTo-Json -Depth 5 | Set-Content -Path $storeFile -Encoding UTF8
}
function Is-IPv4([string]$ip) {
    $parsed = $null
    return [System.Net.IPAddress]::TryParse($ip, [ref]$parsed) -and
        $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
}

$form = New-Object Windows.Forms.Form
$form.Text = "DNS Profile Manager"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object Drawing.Size(540, 510)
$form.MinimumSize = New-Object Drawing.Size(540, 510)
$form.Font = New-Object Drawing.Font("Segoe UI", 10)
$form.BackColor = [Drawing.Color]::FromArgb(247, 248, 250)
$iconPath = Join-Path $PSScriptRoot "DnsProfileManager.ico"
$appIcon = $null
if (Test-Path $iconPath) { try { $appIcon = New-Object System.Drawing.Icon($iconPath); $form.Icon = $appIcon } catch {} }

$title = New-Object Windows.Forms.Label
$title.Text = "DNS Profiles"
$title.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$title.Location = New-Object Drawing.Point(22, 16)
$title.Size = New-Object Drawing.Size(300, 36)
$form.Controls.Add($title)

$adapterLabel = New-Object Windows.Forms.Label
$adapterLabel.Text = "Network adapter:"
$adapterLabel.Location = New-Object Drawing.Point(24, 65)
$adapterLabel.Size = New-Object Drawing.Size(125, 25)
$form.Controls.Add($adapterLabel)

$adapterBox = New-Object Windows.Forms.ComboBox
$adapterBox.Location = New-Object Drawing.Point(155, 61)
$adapterBox.Size = New-Object Drawing.Size(345, 30)
$adapterBox.DropDownStyle = "DropDownList"
try {
    Get-NetAdapter | Where-Object { $_.Name } | Sort-Object Name | ForEach-Object { [void]$adapterBox.Items.Add($_.Name) }
} catch {}
if ($adapterBox.Items.Contains("Wi-Fi")) { $adapterBox.SelectedItem = "Wi-Fi" }
elseif ($adapterBox.Items.Count -gt 0) { $adapterBox.SelectedIndex = 0 }
$form.Controls.Add($adapterBox)

$listLabel = New-Object Windows.Forms.Label
$listLabel.Text = "Saved DNS profiles:"
$listLabel.Location = New-Object Drawing.Point(24, 105)
$listLabel.Size = New-Object Drawing.Size(200, 25)
$form.Controls.Add($listLabel)

$list = New-Object Windows.Forms.ListBox
$list.Location = New-Object Drawing.Point(24, 133)
$list.Size = New-Object Drawing.Size(476, 190)
$list.Font = New-Object Drawing.Font("Segoe UI", 11)
$list.IntegralHeight = $false
$form.Controls.Add($list)

$status = New-Object Windows.Forms.Label
$status.Text = "Select a profile from the list."
$status.Location = New-Object Drawing.Point(24, 331)
$status.Size = New-Object Drawing.Size(476, 26)
$status.ForeColor = [Drawing.Color]::FromArgb(75, 85, 99)
$form.Controls.Add($status)

$toggle = New-Object Windows.Forms.Button
$toggle.Text = "Connect"
$toggle.Location = New-Object Drawing.Point(24, 365)
$toggle.Size = New-Object Drawing.Size(476, 58)
$toggle.Font = New-Object Drawing.Font("Segoe UI Semibold", 14)
$toggle.FlatStyle = "Flat"
$toggle.BackColor = [Drawing.Color]::FromArgb(37, 99, 235)
$toggle.ForeColor = [Drawing.Color]::White
$form.Controls.Add($toggle)

$add = New-Object Windows.Forms.Button
$add.Text = "+ Add DNS"
$add.Location = New-Object Drawing.Point(24, 435)
$add.Size = New-Object Drawing.Size(105, 32)
$form.Controls.Add($add)

$edit = New-Object Windows.Forms.Button
$edit.Text = "Edit"
$edit.Location = New-Object Drawing.Point(137, 435)
$edit.Size = New-Object Drawing.Size(85, 32)
$form.Controls.Add($edit)

$remove = New-Object Windows.Forms.Button
$remove.Text = "Remove"
$remove.Location = New-Object Drawing.Point(230, 435)
$remove.Size = New-Object Drawing.Size(115, 32)
$form.Controls.Add($remove)

$refresh = New-Object Windows.Forms.Button
$refresh.Text = "Refresh adapters"
$refresh.Location = New-Object Drawing.Point(356, 435)
$refresh.Size = New-Object Drawing.Size(144, 32)
$form.Controls.Add($refresh)

function Refresh-List {
    $list.Items.Clear()
    foreach ($profile in $profiles) { [void]$list.Items.Add([string]$profile.Name) }
    if ($list.Items.Count -gt 0 -and $list.SelectedIndex -lt 0) { $list.SelectedIndex = 0 }
    Update-ConnectionState
}
function Get-SelectedProfile {
    if ($list.SelectedIndex -lt 0) { return $null }
    $name = [string]$list.SelectedItem
    return $profiles | Where-Object { $_.Name -eq $name } | Select-Object -First 1
}
function Update-ConnectionState {
    $profile = Get-SelectedProfile
    if (-not $profile) {
        $status.Text = "Add or select a DNS profile."
        $toggle.Text = "Connect"
        $toggle.Enabled = $false
        $edit.Enabled = $false
        $remove.Enabled = $false
        return
    }
    $edit.Enabled = $true
    $remove.Enabled = $true
    $toggle.Enabled = ($adapterBox.SelectedItem -ne $null)
    $isActive = $false
    try {
        $current = @(Get-DnsClientServerAddress -InterfaceAlias ([string]$adapterBox.SelectedItem) -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object { $_.ServerAddresses } | Where-Object { $_ })
        $expected = @([string]$profile.DNS1, [string]$profile.DNS2) | Where-Object { $_ }
        $isActive = ($current.Count -eq $expected.Count -and
            (@(Compare-Object -ReferenceObject $expected -DifferenceObject $current).Count -eq 0))
    } catch {}
    if ($isActive) {
        $status.Text = "Connected: $($profile.Name)"
        $status.ForeColor = [Drawing.Color]::FromArgb(22, 130, 70)
        $toggle.Text = "Disconnect"
        $toggle.BackColor = [Drawing.Color]::FromArgb(185, 55, 55)
    } else {
        $status.Text = "Not connected to the selected profile."
        $status.ForeColor = [Drawing.Color]::FromArgb(75, 85, 99)
        $toggle.Text = "Connect"
        $toggle.BackColor = [Drawing.Color]::FromArgb(37, 99, 235)
    }
}
function Show-ProfileDialog($existing) {
    $oldName = $null
    if ($existing) { $oldName = [string]$existing.Name }
    $dialog = New-Object Windows.Forms.Form
    if ($existing) { $dialog.Text = "Edit DNS profile" } else { $dialog.Text = "Add DNS profile" }
    $dialog.StartPosition = "CenterParent"
    $dialog.Size = New-Object Drawing.Size(390, 285)
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.Font = New-Object Drawing.Font("Segoe UI", 10)
    if ($appIcon) { $dialog.Icon = $appIcon }
    $labels = @("Profile name:", "DNS 1:", "DNS 2:")
    $ys = @(22, 72, 122)
    for ($i=0; $i -lt 3; $i++) {
        $lab = New-Object Windows.Forms.Label
        $lab.Text = $labels[$i]
        $lab.Location = New-Object Drawing.Point(20, $ys[$i])
        $lab.Size = New-Object Drawing.Size(100, 25)
        $dialog.Controls.Add($lab)
    }
    $nameBox = New-Object Windows.Forms.TextBox
    $nameBox.Location = New-Object Drawing.Point(125, 19)
    $nameBox.Size = New-Object Drawing.Size(220, 28)
    $dialog.Controls.Add($nameBox)
    $dns1Box = New-Object Windows.Forms.TextBox
    $dns1Box.Location = New-Object Drawing.Point(125, 69)
    $dns1Box.Size = New-Object Drawing.Size(220, 28)
    $dialog.Controls.Add($dns1Box)
    $dns2Box = New-Object Windows.Forms.TextBox
    $dns2Box.Location = New-Object Drawing.Point(125, 119)
    $dns2Box.Size = New-Object Drawing.Size(220, 28)
    $dialog.Controls.Add($dns2Box)
    if ($existing) {
        $nameBox.Text = [string]$existing.Name
        $dns1Box.Text = [string]$existing.DNS1
        $dns2Box.Text = [string]$existing.DNS2
    }
    $save = New-Object Windows.Forms.Button
    $save.Text = "Save"
    $save.Location = New-Object Drawing.Point(125, 174)
    $save.Size = New-Object Drawing.Size(100, 34)
    $save.DialogResult = [Windows.Forms.DialogResult]::None
    $save.Add_Click({
        $n = $nameBox.Text.Trim()
        $a = $dns1Box.Text.Trim()
        $b = $dns2Box.Text.Trim()
        if (-not $n -or -not (Is-IPv4 $a) -or -not (Is-IPv4 $b)) {
            [Windows.Forms.MessageBox]::Show("Enter a profile name and two valid IPv4 addresses.", "Invalid input", "OK", "Warning") | Out-Null
            return
        }
        if (@($profiles | Where-Object { $_.Name -eq $n -and $_.Name -ne $oldName }).Count -gt 0) {
            [Windows.Forms.MessageBox]::Show("A profile with this name already exists.", "Duplicate name", "OK", "Warning") | Out-Null
            return
        }
        $newProfile = [pscustomobject]@{ Name=$n; DNS1=$a; DNS2=$b }
        if ($oldName) {
            $script:profiles = @($profiles | ForEach-Object { if ($_.Name -eq $oldName) { $newProfile } else { $_ } })
        } else {
            $script:profiles += $newProfile
        }
        Save-Profiles
        $dialog.Tag = $n
        $dialog.Close()
    })
    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Location = New-Object Drawing.Point(245, 174)
    $cancel.Size = New-Object Drawing.Size(100, 34)
    $cancel.Add_Click({ $dialog.Close() })
    $dialog.Controls.AddRange(@($save, $cancel))
    $dialog.AcceptButton = $save
    $dialog.CancelButton = $cancel
    [void]$dialog.ShowDialog($form)
    if ($dialog.Tag) { Refresh-List; $list.SelectedItem = [string]$dialog.Tag }
}

$list.Add_SelectedIndexChanged({ Update-ConnectionState })
$adapterBox.Add_SelectedIndexChanged({ Update-ConnectionState })
$add.Add_Click({ Show-ProfileDialog $null })
$edit.Add_Click({
    $selected = Get-SelectedProfile
    if ($selected) { Show-ProfileDialog $selected }
})
$list.Add_DoubleClick({
    $selected = Get-SelectedProfile
    if ($selected) { Show-ProfileDialog $selected }
})
$remove.Add_Click({
    $profile = Get-SelectedProfile
    if (-not $profile) { return }
    $answer = [Windows.Forms.MessageBox]::Show("Remove profile '$($profile.Name)' from the list?", "Confirm", "YesNo", "Question")
    if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
        $script:profiles = @($profiles | Where-Object { $_.Name -ne $profile.Name })
        Save-Profiles
        Refresh-List
    }
})
$refresh.Add_Click({
    $previous = [string]$adapterBox.SelectedItem
    $adapterBox.Items.Clear()
    try { Get-NetAdapter | Where-Object { $_.Name } | Sort-Object Name | ForEach-Object { [void]$adapterBox.Items.Add($_.Name) } } catch {}
    if ($adapterBox.Items.Contains($previous)) { $adapterBox.SelectedItem = $previous }
    elseif ($adapterBox.Items.Contains("Wi-Fi")) { $adapterBox.SelectedItem = "Wi-Fi" }
    elseif ($adapterBox.Items.Count -gt 0) { $adapterBox.SelectedIndex = 0 }
    Update-ConnectionState
})
$toggle.Add_Click({
    $profile = Get-SelectedProfile
    $adapter = [string]$adapterBox.SelectedItem
    if (-not $profile -or -not $adapter) { return }
    try {
        $current = @(Get-DnsClientServerAddress -InterfaceAlias $adapter -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object { $_.ServerAddresses } | Where-Object { $_ })
        $expected = @([string]$profile.DNS1, [string]$profile.DNS2) | Where-Object { $_ }
        $active = ($current.Count -eq $expected.Count -and
            (@(Compare-Object -ReferenceObject $expected -DifferenceObject $current).Count -eq 0))
        if ($active) {
            Set-DnsClientServerAddress -InterfaceAlias $adapter -ResetServerAddresses -ErrorAction Stop
        } else {
            Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses @([string]$profile.DNS1, [string]$profile.DNS2) -ErrorAction Stop
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Update-ConnectionState
    } catch {
        [Windows.Forms.MessageBox]::Show("Could not change DNS.`r`n$($_.Exception.Message)", "DNS error", "OK", "Error") | Out-Null
    }
})
Refresh-List
[void]$form.ShowDialog()
