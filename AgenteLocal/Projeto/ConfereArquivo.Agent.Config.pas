unit ConfereArquivo.Agent.Config;

interface

uses
  System.SysUtils, System.Types;

type
  TConfereAgentConfig = record
    AppRoot: string;
    ExeRoot: string;
    ConfigFileName: string;
    LogPath: string;
    QueueDatabasePath: string;
    SourceDatabasePath: string;
    SourceDatabasePaths: TStringDynArray;
    EnabledNFCe: Boolean;
    NFCeDatabasePath: string;
    NFCeDatabasePaths: TStringDynArray;
    EnabledNFeSaida: Boolean;
    NFeSaidaDatabasePath: string;
    NFeSaidaDatabasePaths: TStringDynArray;
    EnabledNFeEntrada: Boolean;
    FirebirdUser: string;
    FirebirdPassword: string;
    ApiBaseUrl: string;
    ApiToken: string;
    InstalacaoID: string;
    IntervalSeconds: Integer;
    WindowDays: Integer;
    Enabled: Boolean;
    FirstRunPending: Boolean;
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

function ExeRootPath: string;
begin
  Result := ExcludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
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

function LoadSectionDatabasePaths(const AIni: TIniFile; const ASection: string): TStringDynArray;
var
  Count, I: Integer;
  Value: string;
  L: TStringDynArray;
begin
  Count := AIni.ReadInteger(ASection, 'Count', 0);
  if Count > 0 then
  begin
    SetLength(L, Count);
    for I := 0 to Count - 1 do
      L[I] := Trim(AIni.ReadString(ASection, Format('Database%d', [I + 1]), ''));
    Exit(FilterDatabasePaths(L));
  end;

  SetLength(Result, 0);
end;

function LoadLegacyDatabasePaths(const AIni: TIniFile): TStringDynArray;
var
  Value: string;
  L: TStringDynArray;
begin
  Result := LoadSectionDatabasePaths(AIni, 'Bancos');
  if Length(Result) > 0 then
    Exit;

  Value := Trim(AIni.ReadString('Banco', 'Database', ''));
  if Value <> '' then
  begin
    SetLength(L, 1);
    L[0] := Value;
    Exit(FilterDatabasePaths(L));
  end;

  SetLength(Result, 0);
end;

procedure SaveSectionDatabasePaths(const AIni: TIniFile; const ASection, AFallbackSection, AFallbackKey: string;
  const APaths: TStringDynArray);
var
  I: Integer;
  Paths: TStringDynArray;
begin
  Paths := FilterDatabasePaths(APaths);
  AIni.EraseSection(ASection);
  AIni.WriteInteger(ASection, 'Count', Length(Paths));
  for I := 0 to High(Paths) do
    AIni.WriteString(ASection, Format('Database%d', [I + 1]), Paths[I]);

  if AFallbackSection <> '' then
  begin
    if Length(Paths) > 0 then
      AIni.WriteString(AFallbackSection, AFallbackKey, Paths[0])
    else
      AIni.WriteString(AFallbackSection, AFallbackKey, '');
  end;
end;

function ReadDiscoveredPath(const AConfigFile, ASection, AKey: string): string;
var
  Ini: TIniFile;
begin
  Result := '';
  if not FileExists(AConfigFile) then
    Exit;

  Ini := TIniFile.Create(AConfigFile);
  try
    Result := Trim(Ini.ReadString(ASection, AKey, ''));
    if Result <> '' then
      Result := ExpandFileName(Result);
  finally
    Ini.Free;
  end;
end;

procedure ApplyDiscoveredPath(var APaths: TStringDynArray; const ADiscoveredPath: string);
var
  L: TStringDynArray;
begin
  if (ADiscoveredPath = '') or (not FileExists(ADiscoveredPath)) then
    Exit;

  SetLength(L, 1);
  L[0] := ADiscoveredPath;
  APaths := FilterDatabasePaths(L);
end;

function SinglePathArray(const AValue: string): TStringDynArray;
begin
  if Trim(AValue) = '' then
    SetLength(Result, 0)
  else
  begin
    SetLength(Result, 1);
    Result[0] := Trim(AValue);
  end;
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
    Ini.WriteInteger('NFCe', 'Count', 1);
    Ini.WriteString('NFCe', 'Database1', ExpandFileName('C:\DEV\Confere_Arquivo\PAFECF.FDB'));
    Ini.WriteBool('NFCe', 'Ativo', True);
    Ini.WriteInteger('NFeSaida', 'Count', 1);
    Ini.WriteString('NFeSaida', 'Database1', ExpandFileName('C:\DEV\Confere_Arquivo\BANCO.GDB'));
    Ini.WriteBool('NFeSaida', 'Ativo', True);
    Ini.WriteBool('NFeEntrada', 'Ativo', True);
    Ini.WriteString('Banco', 'Database', ExpandFileName('C:\DEV\Confere_Arquivo\PAFECF.FDB'));
    Ini.WriteString('Banco', 'DatabaseNFeSaida', ExpandFileName('C:\DEV\Confere_Arquivo\BANCO.GDB'));
    Ini.WriteString('Banco', 'User_Name', 'SYSDBA');
    Ini.WriteString('Banco', 'Password', 'masterkey');
    Ini.WriteString('Servidor', 'BaseUrl', 'http://qualifazentregas.vps-kinghost.net');
    Ini.WriteString('Servidor', 'Token', '6c0990ebb3e5ea1b5c356abc81675280e104d6bf3e2e4f10');
    Ini.WriteString('Agente', 'InstalacaoID', DefaultInstalacaoID);
    Ini.WriteInteger('Agente', 'IntervaloSegundos', 15);
    Ini.WriteInteger('Agente', 'JanelaDias', 3);
    Ini.WriteBool('Agente', 'Ativo', False);
    Ini.WriteBool('Agente', 'PrimeiraExecucao', True);
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
  AConfig.ExeRoot := ExeRootPath;
  AConfig.ConfigFileName := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config\ConfereArquivo.ini';
  AConfig.LogPath := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Logs';
  AConfig.QueueDatabasePath := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config\ConfereArquivoQueue.sqlite';

  EnsureDirectory(IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config');
  EnsureDirectory(AConfig.LogPath);
  EnsureDefaultIni(AConfig.ConfigFileName);

  Ini := TIniFile.Create(AConfig.ConfigFileName);
  try
    AConfig.NFCeDatabasePaths := LoadSectionDatabasePaths(Ini, 'NFCe');
    if Length(AConfig.NFCeDatabasePaths) = 0 then
      AConfig.NFCeDatabasePaths := LoadLegacyDatabasePaths(Ini);
    AConfig.EnabledNFCe := Ini.ReadBool('NFCe', 'Ativo', True);

    AConfig.NFeSaidaDatabasePaths := LoadSectionDatabasePaths(Ini, 'NFeSaida');
    if Length(AConfig.NFeSaidaDatabasePaths) = 0 then
      AConfig.NFeSaidaDatabasePaths := FilterDatabasePaths(
        SinglePathArray(Trim(Ini.ReadString('Banco', 'DatabaseNFeSaida', ''))));
    AConfig.EnabledNFeSaida := Ini.ReadBool('NFeSaida', 'Ativo', True);
    AConfig.EnabledNFeEntrada := Ini.ReadBool('NFeEntrada', 'Ativo', True);

    ApplyDiscoveredPath(AConfig.NFCeDatabasePaths,
      ReadDiscoveredPath(IncludeTrailingPathDelimiter(AConfig.ExeRoot) + 'ConfigNFCe.ini', 'BANCO', 'LOCAL'));
    ApplyDiscoveredPath(AConfig.NFeSaidaDatabasePaths,
      ReadDiscoveredPath(IncludeTrailingPathDelimiter(AConfig.ExeRoot) + 'ConfigLocal.ini', 'ConfiguracaoLocal', 'database'));

    if Length(AConfig.NFCeDatabasePaths) > 0 then
      AConfig.NFCeDatabasePath := AConfig.NFCeDatabasePaths[0]
    else
      AConfig.NFCeDatabasePath := '';

    if Length(AConfig.NFeSaidaDatabasePaths) > 0 then
      AConfig.NFeSaidaDatabasePath := AConfig.NFeSaidaDatabasePaths[0]
    else
      AConfig.NFeSaidaDatabasePath := '';

    AConfig.SourceDatabasePaths := AConfig.NFCeDatabasePaths;
    AConfig.SourceDatabasePath := AConfig.NFCeDatabasePath;
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
    AConfig.Enabled := Ini.ReadBool('Agente', 'Ativo', False);
    AConfig.FirstRunPending := Ini.ReadBool('Agente', 'PrimeiraExecucao', False);
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
    SaveSectionDatabasePaths(Ini, 'NFCe', 'Banco', 'Database', AConfig.NFCeDatabasePaths);
    SaveSectionDatabasePaths(Ini, 'NFeSaida', 'Banco', 'DatabaseNFeSaida', AConfig.NFeSaidaDatabasePaths);
    Ini.WriteBool('NFCe', 'Ativo', AConfig.EnabledNFCe);
    Ini.WriteBool('NFeSaida', 'Ativo', AConfig.EnabledNFeSaida);
    Ini.WriteBool('NFeEntrada', 'Ativo', AConfig.EnabledNFeEntrada);
    Ini.WriteString('Banco', 'User_Name', AConfig.FirebirdUser);
    Ini.WriteString('Banco', 'Password', AConfig.FirebirdPassword);
    Ini.WriteString('Servidor', 'BaseUrl', AConfig.ApiBaseUrl);
    Ini.WriteString('Servidor', 'Token', AConfig.ApiToken);
    Ini.WriteString('Agente', 'InstalacaoID', AConfig.InstalacaoID);
    Ini.WriteInteger('Agente', 'IntervaloSegundos', AConfig.IntervalSeconds);
    Ini.WriteInteger('Agente', 'JanelaDias', AConfig.WindowDays);
    Ini.WriteBool('Agente', 'Ativo', AConfig.Enabled);
    Ini.WriteBool('Agente', 'PrimeiraExecucao', AConfig.FirstRunPending);
    Ini.WriteBool('Agente', 'IniciarComWindows', AConfig.StartWithWindows);
  finally
    Ini.Free;
  end;
  ApplyStartupSetting(AConfig.StartWithWindows);
end;

end.
