; Z Privacy for Windows — one file instead of thirteen.
;
; A Flutter application on Windows is `zprivacy.exe` (88 KB) plus
; `flutter_windows.dll` (21 MB), `z_bridge.dll`, a plugin DLL and `data/` in
; four nested folders beside it. Handing that over as a zip asks a person to
; unblock it, extract it to the right place, and never move the executable out
; of its folder — and when they get one of those wrong, nothing happens at all,
; with no message. That silence is what this file removes.
;
; It installs per user, into %LOCALAPPDATA%\Programs, so Windows never asks for
; an administrator. The wizard is two clicks: Install, then Finish with the app
; already starting.
;
; What it does NOT remove is SmartScreen. That wall comes down with a code
; signing certificate and nothing else; the `SignTool` line at the bottom is
; where it goes on the day there is one.
;
; Built by `.github/workflows/windows-core.yml`, which passes SourceDir, OutDir
; and AppVersion in. Nothing here is written twice.

#ifndef SourceDir
  #error SourceDir must be passed in: iscc /DSourceDir=...
#endif
#ifndef OutDir
  #define OutDir "."
#endif
#ifndef AppVersion
  #error AppVersion must be passed in, read from pubspec.yaml
#endif
#ifndef IconFile
  #error IconFile must be passed in: the application's own .ico
#endif

#define AppName     "Z Privacy"
#define Publisher   "Faruk AB"
#define AppURL      "https://z-privacy.com"
#define ExeName     "zprivacy.exe"

[Setup]
; Stable for the life of the product. Change it and Windows stops seeing an
; upgrade and starts seeing a second application beside the first.
AppId={{6D8283C4-04E9-58F1-949D-4E3F74F568C8}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#Publisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#Publisher}
VersionInfoCopyright=© 2026 Faruk AB — Apache License 2.0

; Per user. `{autopf}` becomes %LOCALAPPDATA%\Programs under `lowest`, so there
; is no administrator prompt and no second password to explain to somebody.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#ExeName}
UninstallDisplayName={#AppName}

; Every page that is not a decision is gone. What is left is Install and
; Finish. There is no licence page because Apache-2.0 asks nobody to click
; «I agree»; the licence travels with the application and is named above.
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
WizardStyle=modern
SetupIconFile={#IconFile}

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

Compression=lzma2/max
SolidCompression=yes
OutputDir={#OutDir}
OutputBaseFilename=zprivacy-v1-windows-x86_64-setup

[Languages]
; The two the first testers read. Inno picks by the system language, so a
; German Windows shows German without anybody choosing.
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german";  MessagesFile: "compiler:Languages\German.isl"

[Files]
; The whole folder, with its four levels of `data/`, exactly as the build made
; it. `recursesubdirs` and `createallsubdirs` are what keep the thirteen files
; in the arrangement the application needs.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Both, without asking. A person who has just installed something should not
; have to go looking for it, and a checkbox about shortcuts is a page.
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#ExeName}"
Name: "{autodesktop}\{#AppName}";  Filename: "{app}\{#ExeName}"

[Run]
Filename: "{app}\{#ExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; On the day there is a certificate, this is the whole change — and the runner
; is told what `signtool` means with `iscc /Ssigntool=...`:
;
;   SignTool=signtool
;   SignedUninstaller=yes
