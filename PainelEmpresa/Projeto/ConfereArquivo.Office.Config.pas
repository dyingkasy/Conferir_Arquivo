unit ConfereArquivo.Office.Config;

interface

uses
  System.SysUtils;

type
  TConfereOfficeConfig = record
    AppRoot: string;
    ConfigFileName: string;
    LogPath: string;
    ApiBaseUrl: string;
    ApiToken: string;
    CNPJEmpresa: string;
    DocumentoTipo: string;
    DiasResumo: Integer;
  end;

procedure LoadOfficeConfig(out AConfig: TConfereOfficeConfig);
procedure SaveOfficeConfig(const AConfig: TConfereOfficeConfig);

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

procedure EnsureDefaultIni(const AFileName: string);
var
  Ini: TIniFile;
begin
  if FileExists(AFileName) then
    Exit;

  Ini := TIniFile.Create(AFileName);
  try
    Ini.WriteString('Servidor', 'BaseUrl', 'http://qualifazentregas.vps-kinghost.net');
    Ini.WriteString('Servidor', 'Token', '6c0990ebb3e5ea1b5c356abc81675280e104d6bf3e2e4f10');
    Ini.WriteString('Empresa', 'CNPJ', '12345678000199');
    Ini.WriteString('Painel', 'DocumentoTipo', 'NFCE');
    Ini.WriteInteger('Painel', 'DiasResumo', 7);
  finally
    Ini.Free;
  end;
end;

procedure LoadOfficeConfig(out AConfig: TConfereOfficeConfig);
var
  Ini: TIniFile;
begin
  FillChar(AConfig, SizeOf(AConfig), 0);
  AConfig.AppRoot := AppRootPath;
  AConfig.ConfigFileName := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config\ConfereArquivoOffice.ini';
  AConfig.LogPath := IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Logs';
  EnsureDirectory(IncludeTrailingPathDelimiter(AConfig.AppRoot) + 'Config');
  EnsureDirectory(AConfig.LogPath);
  EnsureDefaultIni(AConfig.ConfigFileName);

  Ini := TIniFile.Create(AConfig.ConfigFileName);
  try
    AConfig.ApiBaseUrl := Trim(Ini.ReadString('Servidor', 'BaseUrl', ''));
    AConfig.ApiToken := Trim(Ini.ReadString('Servidor', 'Token', ''));
    AConfig.CNPJEmpresa := Trim(Ini.ReadString('Empresa', 'CNPJ', ''));
    AConfig.DocumentoTipo := UpperCase(Trim(Ini.ReadString('Painel', 'DocumentoTipo', 'NFCE')));
    if (AConfig.DocumentoTipo <> 'NFCE') and (AConfig.DocumentoTipo <> 'NFE_SAIDA') then
      AConfig.DocumentoTipo := 'NFCE';
    AConfig.DiasResumo := Ini.ReadInteger('Painel', 'DiasResumo', 7);
    if AConfig.DiasResumo <= 0 then
      AConfig.DiasResumo := 7;
  finally
    Ini.Free;
  end;
end;

procedure SaveOfficeConfig(const AConfig: TConfereOfficeConfig);
var
  Ini: TIniFile;
begin
  EnsureDefaultIni(AConfig.ConfigFileName);
  Ini := TIniFile.Create(AConfig.ConfigFileName);
  try
    Ini.WriteString('Servidor', 'BaseUrl', AConfig.ApiBaseUrl);
    Ini.WriteString('Servidor', 'Token', AConfig.ApiToken);
    Ini.WriteString('Empresa', 'CNPJ', AConfig.CNPJEmpresa);
    Ini.WriteString('Painel', 'DocumentoTipo', AConfig.DocumentoTipo);
    Ini.WriteInteger('Painel', 'DiasResumo', AConfig.DiasResumo);
  finally
    Ini.Free;
  end;
end;

end.
