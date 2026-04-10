unit ConfereArquivo.Logger;

interface

uses
  System.SysUtils;

procedure ConfigureConfereLogger(const ALogDir: string);
procedure ConfereLogOperational(const AMessage: string);
procedure ConfereLogError(const AMessage: string);

implementation

var
  GLogDir: string = '';

procedure EnsureLogDir;
begin
  if (GLogDir <> '') and (not DirectoryExists(GLogDir)) then
    ForceDirectories(GLogDir);
end;

procedure AppendLine(const AFileName, AMessage: string);
var
  LFile: TextFile;
begin
  EnsureLogDir;
  AssignFile(LFile, AFileName);
  if FileExists(AFileName) then
    Append(LFile)
  else
    Rewrite(LFile);
  try
    Writeln(LFile, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + '  ' + AMessage);
  finally
    CloseFile(LFile);
  end;
end;

procedure ConfigureConfereLogger(const ALogDir: string);
begin
  GLogDir := ExcludeTrailingPathDelimiter(ALogDir);
  EnsureLogDir;
end;

procedure ConfereLogOperational(const AMessage: string);
begin
  AppendLine(IncludeTrailingPathDelimiter(GLogDir) +
    'operacional_' + FormatDateTime('yyyymmdd', Date) + '.log', AMessage);
end;

procedure ConfereLogError(const AMessage: string);
begin
  AppendLine(IncludeTrailingPathDelimiter(GLogDir) +
    'erro_' + FormatDateTime('yyyymmdd', Date) + '.log', AMessage);
end;

end.
