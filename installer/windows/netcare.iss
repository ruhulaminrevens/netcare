#define MyAppName "RAR NetCare"
#define MyAppVersion "1.1.2"
#define MyAppPublisher "Ruhul Amin Revens"
#define MyAppExeName "ruhul_netcare.exe"
#define MyAppURL "https://github.com/ruhulaminrevens/netcare"
#define SourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{A25E79D0-8634-4C66-9C0B-7AD0B4CD3B9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\RAR NetCare
DefaultGroupName=RAR NetCare
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=RAR-NetCare-Setup-{#MyAppVersion}-x64
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
LicenseFile=..\..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\RAR NetCare"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\RAR NetCare"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch RAR NetCare"; Flags: nowait postinstall skipifsilent
