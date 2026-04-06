[Setup]
AppName=구술기록관리 에이전트
AppVersion=2.0
AppPublisher=OralRecordAgent
AppPublisherURL=https://github.com/yimjhkr68/oral-record-agent
DefaultDirName={autopf}\OralRecordAgent
DefaultGroupName=구술기록관리 에이전트
OutputDir=installer_output
OutputBaseFilename=oral_record_agent_v2.0_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕화면 바로가기 만들기"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "scripts\*"; DestDir: "{app}\scripts"; Flags: recursesubdirs
Source: "README_설치안내.txt"; DestDir: "{app}"

[Icons]
Name: "{group}\구술기록관리 에이전트"; Filename: "{app}\oral_record_agent.exe"
Name: "{commondesktop}\구술기록관리 에이전트"; Filename: "{app}\oral_record_agent.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\oral_record_agent.exe"; Description: "앱 실행"; Flags: nowait postinstall skipifsilent
