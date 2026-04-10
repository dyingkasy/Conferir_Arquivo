program ConfereArquivoApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Horse.Jhonson,
  ConfereArquivo.Api.Config in 'ConfereArquivo.Api.Config.pas',
  ConfereArquivo.Api.Database in 'ConfereArquivo.Api.Database.pas',
  ConfereArquivo.Logger in '..\..\Common\ConfereArquivo.Logger.pas';

var
  Config: TConfereApiConfig;
  Db: TConfereApiDatabase;

function AuthToken(const Req: THorseRequest): string;
var
  HeaderValue: string;
begin
  HeaderValue := Trim(Req.Headers['Authorization']);
  if HeaderValue.StartsWith('Bearer ', True) then
    Result := Trim(Copy(HeaderValue, 8, MaxInt))
  else
    Result := HeaderValue;
end;

function RemoteIp(const Req: THorseRequest): string;
begin
  Result := Req.Headers['X-Forwarded-For'];
  if Result = '' then
    Result := Req.RawWebRequest.RemoteIP;
end;

procedure SendJson(Res: THorseResponse; Obj: TJSONObject);
begin
  try
    Res.ContentType('application/json').Send(Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

procedure HealthHandler(Req: THorseRequest; Res: THorseResponse);
begin
  SendJson(Res,
    TJSONObject.Create
      .AddPair('status', 'ok')
      .AddPair('servico', 'ConfereArquivo API')
      .AddPair('porta', TJSONNumber.Create(Config.ListenPort))
      .AddPair('database', Config.PgDatabase));
end;

procedure ConfigCheckHandler(Req: THorseRequest; Res: THorseResponse);
var
  Body: TJSONObject;
  Token, CNPJ, Razao: string;
begin
  Body := Req.Body<TJSONObject>;
  if not Assigned(Body) then
    raise Exception.Create('Body JSON obrigatorio.');
  Token := AuthToken(Req);
  CNPJ := Body.GetValue<string>('cnpj_empresa', '');
  Razao := Body.GetValue<string>('razao_social', '');
  if (Token = '') or (CNPJ = '') then
    raise Exception.Create('Token e CNPJ obrigatorios.');

  if not Db.RegisterOrValidateTenant(CNPJ, Token, Razao) then
  begin
    Res.Status(401);
    SendJson(Res,
      TJSONObject.Create
        .AddPair('status', 'unauthorized')
        .AddPair('mensagem', 'Token invalido para a empresa'));
    Exit;
  end;

  Db.SaveHeartbeat(CNPJ, Body.GetValue<string>('instalacao_id', ''), RemoteIp(Req));
  SendJson(Res,
    TJSONObject.Create
      .AddPair('status', 'ok')
      .AddPair('mensagem', 'Configuracao validada.'));
end;

procedure HeartbeatHandler(Req: THorseRequest; Res: THorseResponse);
var
  Body: TJSONObject;
  Token, CNPJ: string;
begin
  Body := Req.Body<TJSONObject>;
  if not Assigned(Body) then
    raise Exception.Create('Body JSON obrigatorio.');
  Token := AuthToken(Req);
  CNPJ := Body.GetValue<string>('cnpj_empresa', '');
  if not Db.RegisterOrValidateTenant(CNPJ, Token, '') then
  begin
    Res.Status(401).Send('unauthorized');
    Exit;
  end;

  Db.SaveHeartbeat(CNPJ, Body.GetValue<string>('instalacao_id', ''), RemoteIp(Req));
  SendJson(Res,
    TJSONObject.Create
      .AddPair('status', 'ok')
      .AddPair('mensagem', 'Heartbeat recebido.'));
end;

procedure LoteHandler(Req: THorseRequest; Res: THorseResponse);
var
  Body: TJSONObject;
begin
  Body := Req.Body<TJSONObject>;
  if not Assigned(Body) then
    raise Exception.Create('Body JSON obrigatorio.');
  Db.SaveLote(Body, AuthToken(Req), RemoteIp(Req));
  SendJson(Res,
    TJSONObject.Create
      .AddPair('status', 'ok')
      .AddPair('mensagem', 'Lote recebido e persistido.')
      .AddPair('quantidade', TJSONNumber.Create(Body.GetValue<Integer>('quantidade', 0))));
end;

begin
  {$IFDEF MSWINDOWS}
  IsConsole := False;
  {$ENDIF}

  LoadApiConfig(Config);
  ConfigureConfereLogger(Config.LogPath);
    Db := TConfereApiDatabase.Create(Config);
  try
    Db.EnsureSchema;
    THorse.Use(Jhonson);
    THorse.Get('/health', HealthHandler);
    THorse.Post('/api/v1/agente/config-check', ConfigCheckHandler);
    THorse.Post('/api/v1/agente/heartbeat', HeartbeatHandler);
    THorse.Post('/api/v1/nfce/lote', LoteHandler);

    ConfereLogOperational(Format('API ConfereArquivo iniciando na porta %d.', [Config.ListenPort]));
    THorse.Listen(Config.ListenPort);
  finally
    Db.Free;
  end;
end.
