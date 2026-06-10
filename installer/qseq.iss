; QSeq — Windows installer (Inno Setup)
; Builds a per-user setup.exe from the Flutter release build. No admin required.
; Compile with:
;   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\qseq.iss

#define AppName "QSeq"
#define AppVersion "1.2.2"
#define AppPublisher "Meerv Inc."
#define AppExe "QSeq.exe"

[Setup]
AppId={{A3F5C1E2-9B4D-4F8A-8C7E-1D2B3A4C5D6E}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://qseq.app
AppSupportURL=https://github.com/meerv-fmenard/qseq
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=qseq-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
