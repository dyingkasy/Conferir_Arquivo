unit ConfereArquivo.Api.Config;

interface

uses
  System.SysUtils;

type
  TConfereApiConfig = record
    AppRoot: string;
    ConfigFileName: string;
    LogPath: string;
    ListenPort: Integer;
    PgHost: string;
    PgPort: Integer;
    PgDatabase: string;
    PgUser: string;
    PgPassword: string;
    ApiSecret: string;
  end;

procedure LoadApiConfig(out AConfig: TConfereApiConfig);

implementation

uses
  System.IniFiles;

procedure EnsureDirectory(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure EnsureDefaultIni(const AFileName: string);
var
  Ini: TIniFile;
begin
  if FileExists(AFileName) then
    Exit;

  Ini := TIniFile.Create(AFileName);
  try
    Ini.WriteInteger('Servidor', 'Porta', 9015);
    Ini.WriteString('Postgres', 'Host', '127.0.0.1');
    Ini.WriteInteger('Postgres', 'Porta', 5432);
    Ini.WriteString('Postgres', 'Database', 'confere_arquivo');
    Ini.WriteString('Postgres', 'User_Name', 'postgres');
    Ini.WriteString('Postgres', 'Password', 'postgres');
    Ini.WriteString('Seguranca', 'ApiSecret', 'ALTERE-ESTE-TOKEN');
  finally
    Ini.Free;
  end;
end;

procedure LoadApiConfig(out AConfig: TConfereApiConfig);
var
  Ini: TIniFile;
begin
  FillChar(AConfig, SizeOf(AConfig), 0);
  AConfig.AppRoot := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  if SameText(ExtractFileName(AConfig.AppRoot), 'Bin') then
    AConfig.AppRoot := ExpandFileName(IncludeTrailingPathDelimiter(AConfig.AppRoot) + '..');
  AConfig.ConfigFileName := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config\ConfereArquivoApi.ini';
  AConfig.LogPath := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Logs';
  EnsureDirectory(IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config');
  EnsureDirectory(AConfig.LogPath);
  EnsureDefaultIni(AConfig.ConfigFileName);

  Ini := TIniFile.Create(AConfig.ConfigFileName);
  try
    AConfig.ListenPort := Ini.ReadInteger('Servidor', 'Porta', 9015);
    AConfig.PgHost := Trim(Ini.ReadString('Postgres', 'Host', '127.0.0.1'));
    AConfig.PgPort := Ini.ReadInteger('Postgres', 'Porta', 5432);
    AConfig.PgDatabase := Trim(Ini.ReadString('Postgres', 'Database', 'confere_arquivo'));
    AConfig.PgUser := Trim(Ini.ReadString('Postgres', 'User_Name', 'postgres'));
    AConfig.PgPassword := Ini.ReadString('Postgres', 'Password', 'postgres');
    AConfig.ApiSecret := Trim(Ini.ReadString('Seguranca', 'ApiSecret', ''));
  finally
    Ini.Free;
  end;
end;

end.
