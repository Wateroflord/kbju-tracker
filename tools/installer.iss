; Установщик КБЖУ Трекера для Windows (Inno Setup 6). Ставится без прав администратора в профиль пользователя.
#define BuildNo GetEnv("BUILD_NO")
#if BuildNo == ""
  #define BuildNo "0"
#endif

[Setup]
AppId={{3C1B7E62-9A4D-4F8B-B2E7-6D0A5C9F1E24}
AppName=КБЖУ Трекер
AppVersion=1.0.{#BuildNo}
AppPublisher=Winter Hub
DefaultDirName={localappdata}\Programs\KBJU Tracker
DefaultGroupName=КБЖУ Трекер
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=KBJU-Tracker-Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\kbju_tracker.exe
CloseApplications=force
RestartApplications=no
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\КБЖУ Трекер"; Filename: "{app}\kbju_tracker.exe"
Name: "{group}\{cm:UninstallProgram,КБЖУ Трекер}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\КБЖУ Трекер"; Filename: "{app}\kbju_tracker.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\kbju_tracker.exe"; Description: "{cm:LaunchProgram,КБЖУ Трекер}"; Flags: nowait postinstall skipifsilent
; После тихого автообновления — снова запустить приложение.
Filename: "{app}\kbju_tracker.exe"; Flags: nowait; Check: WizardSilent
