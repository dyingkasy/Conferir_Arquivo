unit ConfereArquivo.Agent.Config;

interface

uses
  System.SysUtils, System.Types;

type
  TConfereAgentConfig = record
    AppRoot: string;
    ConfigFileName: string;
    LogPath: string;
    QueueDatabasePath: string;
    SourceDatabasePath: string;
    SourceDatabasePaths: TStringDynArray;
    FirebirdUser: string;
    FirebirdPassword: string;
    ApiBaseUrl: string;
    ApiToken: string;
    InstalacaoID: string;
    IntervalSeconds: Integer;
    WindowDays: Integer;
    Enabled: Boolean;
    StartWithWindows: Boolean;
  end;

procedure LoadAgentConfig(out AConfig: TConfereAgentConfig);
procedure SaveAgentConfig(const AConfig: TConfereAgentConfig);

implementation

uses
  Winapi.Windows, System.Classes, System.IniFiles, System.Win.Registry, Vcl.Forms;

const
  RUN_KEY = '\Software\Microsoft\Windows\CurrentVersion\Run';
  RUN_VALUE_NAME = 'ConfereArquivoAgente';

function AppRootPath: string;
begin
  Result := ExcludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  if SameText(ExtractFileName(Result), 'Bin') then
    Result := ExpandFileName(IncludeTrailingPathDelimiter(Result) + '..');
end;

procedure EnsureDirectory(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

function DefaultInstalacaoID: string;
begin
  Result := StringReplace(StringReplace(GuidToString(TGUID.NewGuid), '{', '', []), '}', '', []);
end;

function FilterDatabasePaths(const AValues: TStringDynArray): TStringDynArray;
var
  Index: Integer;
  Value: string;
  L: TStringList;
  I: Integer;
begin
    L := TStringList.Create;
  try
    L.CaseSensitive := False;
    L.Duplicates := dupIgnore;
    for Index := 0 to High(AValues) do
    begin
      Value := AValues[Index];
      Value := Trim(Value);
      if Value = '' then
        Continue;
      Value := ExpandFileName(Value);
      if L.IndexOf(Value) < 0 then
        L.Add(Value);
    end;

    SetLength(Result, L.Count);
    for I := 0 to L.Count - 1 do
      Result[I] := L[I];
  finally
    L.Free;
  end;
end;

function LoadDatabasePaths(const AIni: TIniFile): TStringDynArray;
var
  Count, I: Integer;
  Value: string;
  L: TStringDynArray;
begin
  Count := AIni.ReadInteger('Bancos', 'Count', 0);
  if Count > 0 then
  begin
    SetLength(L, Count);
    for I := 0 to Count - 1 do
      L[I] := Trim(AIni.ReadString('Bancos', Format('Database%d', [I + 1]), ''));
    Exit(FilterDatabasePaths(L));
  end;

  Value := Trim(AIni.ReadString('Banco', 'Database', ''));
  if Value <> '' then
  begin
    SetLength(L, 1);
    L[0] := Value;
    Exit(FilterDatabasePaths(L));
  end;

  SetLength(Result, 0);
end;

procedure SaveDatabasePaths(const AIni: TIniFile; const APaths: TStringDynArray);
var
  I: Integer;
  Paths: TStringDynArray;
begin
  Paths := FilterDatabasePaths(APaths);
  AIni.EraseSection('Bancos');
  AIni.WriteInteger('Bancos', 'Count', Length(Paths));
  for I := 0 to High(Paths) do
    AIni.WriteString('Bancos', Format('Database%d', [I + 1]), Paths[I]);

  if Length(Paths) > 0 then
    AIni.WriteString('Banco', 'Database', Paths[0])
  else
    AIni.WriteString('Banco', 'Database', '');
end;

function CurrentStartupEnabled: Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(RUN_KEY) then
      Result := Reg.ValueExists(RUN_VALUE_NAME) and (Trim(Reg.ReadString(RUN_VALUE_NAME)) <> '');
  finally
    Reg.Free;
  end;
end;

procedure ApplyStartupSetting(const AEnabled: Boolean);
var
  Reg: TRegistry;
  Command: string;
begin
  Reg := TRegistry.Create(KEY_SET_VALUE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(RUN_KEY, True) then
      Exit;

    if AEnabled then
    begin
      Command := Format('"%s" /tray', [Application.ExeName]);
      Reg.WriteString(RUN_VALUE_NAME, Command);
    end
    else if Reg.ValueExists(RUN_VALUE_NAME) then
      Reg.DeleteValue(RUN_VALUE_NAME);
  finally
    Reg.Free;
  end;
end;

procedure EnsureDefaultIni(const AFileName: string);
var
  Ini: TIniFile;
begin
  if FileExists(AFileName) then
    Exit;

  Ini := TIniFile.Create(AFileName);
  try
    Ini.WriteString('Banco', 'Database', ExpandFileName('C:\DEV\Confere_Arquivo\PAFECF.FDB'));
    Ini.WriteInteger('Bancos', 'Count', 1);
    Ini.WriteString('Bancos', 'Database1', ExpandFileName('C:\DEV\Confere_Arquivo\PAFECF.FDB'));
    Ini.WriteString('Banco', 'User_Name', 'SYSDBA');
    Ini.WriteString('Banco', 'Password', 'masterkey');
    Ini.WriteString('Servidor', 'BaseUrl', 'http://qualifazentregas.vps-kinghost.net');
    Ini.WriteString('Servidor', 'Token', '6c0990ebb3e5ea1b5c356abc81675280e104d6bf3e2e4f10');
    Ini.WriteString('Agente', 'InstalacaoID', DefaultInstalacaoID);
    Ini.WriteInteger('Agente', 'IntervaloSegundos', 15);
    Ini.WriteInteger('Agente', 'JanelaDias', 3);
    Ini.WriteBool('Agente', 'Ativo', True);
    Ini.WriteBool('Agente', 'IniciarComWindows', False);
  finally
    Ini.Free;
  end;
end;

procedure LoadAgentConfig(out AConfig: TConfereAgentConfig);
var
  Ini: TIniFile;
begin
  FillChar(AConfig, SizeOf(AConfig), 0);
  AConfig.AppRoot := AppRootPath;
  AConfig.ConfigFileName := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config\ConfereArquivo.ini';
  AConfig.LogPath := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Logs';
  AConfig.QueueDatabasePath := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config\ConfereArquivoQueue.sqlite';

  EnsureDirectory(IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config');
  EnsureDirectory(AConfig.LogPath);
  EnsureDefaultIni(AConfig.ConfigFileName);

  Ini := TIniFile.Create(AConfig.ConfigFileName);
  try
    AConfig.SourceDatabasePaths := LoadDatabasePaths(Ini);
    if Length(AConfig.SourceDatabasePaths) > 0 then
      AConfig.SourceDatabasePath := AConfig.SourceDatabasePaths[0]
    else
      AConfig.SourceDatabasePath := '';
    AConfig.FirebirdUser := Trim(Ini.ReadString('Banco', 'User_Name', 'SYSDBA'));
    AConfig.FirebirdPassword := Trim(Ini.ReadString('Banco', 'Password', 'masterkey'));
    AConfig.ApiBaseUrl := Trim(Ini.ReadString('Servidor', 'BaseUrl', ''));
    AConfig.ApiToken := Trim(Ini.ReadString('Servidor', 'Token', ''));
    AConfig.InstalacaoID := Trim(Ini.ReadString('Agente', 'InstalacaoID', ''));
    if AConfig.InstalacaoID = '' then
      AConfig.InstalacaoID := DefaultInstalacaoID;
    AConfig.IntervalSeconds := Ini.ReadInteger('Agente', 'IntervaloSegundos', 15);
    if AConfig.IntervalSeconds <= 0 then
      AConfig.IntervalSeconds := 15;
    AConfig.WindowDays := Ini.ReadInteger('Agente', 'JanelaDias', 3);
    if AConfig.WindowDays <= 0 then
      AConfig.WindowDays := 3;
    AConfig.Enabled := Ini.ReadBool('Agente', 'Ativo', True);
    AConfig.StartWithWindows := Ini.ReadBool('Agente', 'IniciarComWindows', CurrentStartupEnabled);
  finally
    Ini.Free;
  end;
end;

procedure SaveAgentConfig(const AConfig: TConfereAgentConfig);
var
  Ini: TIniFile;
begin
  EnsureDefaultIni(AConfig.ConfigFileName);
  Ini := TIniFile.Create(AConfig.ConfigFileName);
  try
    SaveDatabasePaths(Ini, AConfig.SourceDatabasePaths);
    Ini.WriteString('Banco', 'User_Name', AConfig.FirebirdUser);
    Ini.WriteString('Banco', 'Password', AConfig.FirebirdPassword);
    Ini.WriteString('Servidor', 'BaseUrl', AConfig.ApiBaseUrl);
    Ini.WriteString('Servidor', 'Token', AConfig.ApiToken);
    Ini.WriteString('Agente', 'InstalacaoID', AConfig.InstalacaoID);
    Ini.WriteInteger('Agente', 'IntervaloSegundos', AConfig.IntervalSeconds);
    Ini.WriteInteger('Agente', 'JanelaDias', AConfig.WindowDays);
    Ini.WriteBool('Agente', 'Ativo', AConfig.Enabled);
    Ini.WriteBool('Agente', 'IniciarComWindows', AConfig.StartWithWindows);
  finally
    Ini.Free;
  end;
  ApplyStartupSetting(AConfig.StartWithWindows);
end;

end.
