; Optional: compile with Inno Setup 6.3+ (https://jrsoftware.org/isinfo.php) to get a single Setup.exe
#define MyAppName "DNS Profile Manager"
#define MyAppVersion "1.1.0"

[Setup]
AppId={{B4D6C1F2-6E0B-4C56-9D7A-2F5B8E3A9C11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallMode=x64compatible
OutputDir=output
OutputBaseFilename=DnsProfileManager-Setup
SetupIconFile=app\DnsProfileManager.ico
UninstallDisplayIcon={app}\DnsProfileManager.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\DnsProfileManager.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\DnsProfileManager.ico"; Tasks: desktopicon

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\Launch.vbs"""; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
