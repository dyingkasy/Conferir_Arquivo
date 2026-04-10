unit ConfereArquivo.Agent.Config;

interface

uses
  System.SysUtils;

type
  TConfereAgentConfig = record
    AppRoot: string;
    ConfigFileName: string;
    LogPath: string;
    QueueDatabasePath: string;
    SourceDatabasePath: string;
    FirebirdUser: string;
    FirebirdPassword: string;
    ApiBaseUrl: string;
    ApiToken: string;
    InstalacaoID: string;
    IntervalSeconds: Integer;
    WindowDays: Integer;
    Enabled: Boolean;
  end;

procedure LoadAgentConfig(out AConfig: TConfereAgentConfig);
procedure SaveAgentConfig(const AConfig: TConfereAgentConfig);

implementation

uses
  System.IniFiles, Vcl.Forms;

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

procedure EnsureDefaultIni(const AFileName: string);
var
  Ini: TIniFile;
begin
  if FileExists(AFileName) then
    Exit;

  Ini := TIniFile.Create(AFileName);
  try
    Ini.WriteString('Banco', 'Database', ExpandFileName('C:\DEV\Confere_Arquivo\PAFECF.FDB'));
    Ini.WriteString('Banco', 'User_Name', 'SYSDBA');
    Ini.WriteString('Banco', 'Password', 'masterkey');
    Ini.WriteString('Servidor', 'BaseUrl', 'http://qualifazentregas.vps-kinghost.net');
    Ini.WriteString('Servidor', 'Token', '6c0990ebb3e5ea1b5c356abc81675280e104d6bf3e2e4f10');
    Ini.WriteString('Agente', 'InstalacaoID', DefaultInstalacaoID);
    Ini.WriteInteger('Agente', 'IntervaloSegundos', 15);
    Ini.WriteInteger('Agente', 'JanelaDias', 3);
    Ini.WriteBool('Agente', 'Ativo', True);
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
    AConfig.SourceDatabasePath := Trim(Ini.ReadString('Banco', 'Database', ''));
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
    Ini.WriteString('Banco', 'Database', AConfig.SourceDatabasePath);
    Ini.WriteString('Banco', 'User_Name', AConfig.FirebirdUser);
    Ini.WriteString('Banco', 'Password', AConfig.FirebirdPassword);
    Ini.WriteString('Servidor', 'BaseUrl', AConfig.ApiBaseUrl);
    Ini.WriteString('Servidor', 'Token', AConfig.ApiToken);
    Ini.WriteString('Agente', 'InstalacaoID', AConfig.InstalacaoID);
    Ini.WriteInteger('Agente', 'IntervaloSegundos', AConfig.IntervalSeconds);
    Ini.WriteInteger('Agente', 'JanelaDias', AConfig.WindowDays);
    Ini.WriteBool('Agente', 'Ativo', AConfig.Enabled);
  finally
    Ini.Free;
  end;
end;

end.
