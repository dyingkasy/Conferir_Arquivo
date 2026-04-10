unit ConfereArquivo.Agent.Sync;

interface

uses
  System.SysUtils,
  ConfereArquivo.Agent.Config, ConfereArquivo.Agent.Source,
  ConfereArquivo.Agent.Queue, ConfereArquivo.Types;

type
  TConfereSyncEngine = class
  private
    FConfig: TConfereAgentConfig;
    FSource: TConfereAgentSource;
    FQueue: TConfereAgentQueue;
    FEmpresa: TConfereEmpresaInfo;
    FLastMessage: string;
    procedure EnsureEmpresaLoaded;
    procedure SendPending;
    function BuildLoteUrl: string;
  public
    constructor Create(const AConfig: TConfereAgentConfig);
    destructor Destroy; override;
    function Validate(out AMessage: string): Boolean;
    function ValidateApi(out AMessage: string): Boolean;
    procedure PollNow;
    procedure SyncTotal;
    function PendingCount: Integer;
    function EmpresaResumo: string;
    property LastMessage: string read FLastMessage;
  end;

implementation

uses
  System.Classes, System.JSON, System.StrUtils, System.Net.URLClient, System.Net.HttpClient,
  System.Net.HttpClientComponent, ConfereArquivo.Json, ConfereArquivo.Logger;

constructor TConfereSyncEngine.Create(const AConfig: TConfereAgentConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FSource := TConfereAgentSource.Create(FConfig);
  FQueue := TConfereAgentQueue.Create(FConfig.QueueDatabasePath);
  FQueue.EnsureSchema;
end;

destructor TConfereSyncEngine.Destroy;
begin
  FQueue.Free;
  FSource.Free;
  inherited Destroy;
end;

function TConfereSyncEngine.Validate(out AMessage: string): Boolean;
begin
  Result := FSource.Validate(AMessage);
end;

function TConfereSyncEngine.BuildLoteUrl: string;
var
  BaseUrl: string;
begin
  BaseUrl := Trim(StringReplace(FConfig.ApiBaseUrl, '\', '/', [rfReplaceAll]));
  while EndsText('/', BaseUrl) do
    Delete(BaseUrl, Length(BaseUrl), 1);

  if BaseUrl = '' then
    Exit('');

  if not EndsText('/api', LowerCase(BaseUrl)) then
    BaseUrl := BaseUrl + '/api';

  Result := BaseUrl + '/v1/nfce/lote';
end;

function TConfereSyncEngine.ValidateApi(out AMessage: string): Boolean;
var
  Client: TNetHTTPClient;
  Req: TStringStream;
  Resp: IHTTPResponse;
  Body: TJSONObject;
  Url: string;
begin
  Result := False;
  AMessage := '';

  EnsureEmpresaLoaded;
  Url := BuildLoteUrl;
  if Url = '' then
  begin
    AMessage := 'BaseUrl nao configurada.';
    Exit;
  end;

  Url := StringReplace(Url, '/nfce/lote', '/agente/config-check', [rfIgnoreCase]);

  Client := TNetHTTPClient.Create(nil);
  try
    Client.ConnectionTimeout := 8000;
    Client.ResponseTimeout := 12000;
    Client.ContentType := 'application/json';
    Client.CustomHeaders['Authorization'] := 'Bearer ' + Trim(FConfig.ApiToken);

    Body := TJSONObject.Create;
    try
      Body.AddPair('cnpj_empresa', NormalizeDigits(FEmpresa.CNPJ));
      Body.AddPair('instalacao_id', FConfig.InstalacaoID);
      Body.AddPair('razao_social', FEmpresa.RazaoSocial);
      Req := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
      try
        Resp := Client.Post(Url, Req);
        Result := (Resp.StatusCode >= 200) and (Resp.StatusCode < 300);
        if Result then
          AMessage := 'Servidor validado com sucesso.'
        else
          AMessage := Format('Falha no servidor. HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
      finally
        Req.Free;
      end;
    finally
      Body.Free;
    end;
  except
    on E: Exception do
      AMessage := E.Message;
  end;
  Client.Free;
end;

procedure TConfereSyncEngine.EnsureEmpresaLoaded;
begin
  if FEmpresa.CNPJ <> '' then
    Exit;

  if not FSource.LoadEmpresa(FEmpresa) then
    raise Exception.Create('Nao foi possivel carregar ECF_EMPRESA.');
end;

procedure TConfereSyncEngine.PollNow;
var
  LastCursor, MaxID: Integer;
  Items: TArray<TConfereNFCeRecord>;
  Item: TConfereNFCeRecord;
  Payload: TJSONObject;
begin
  EnsureEmpresaLoaded;

  LastCursor := FQueue.GetStateInt('last_cursor', 0);
  MaxID := LastCursor;
  Items := FSource.LoadChangedSales(LastCursor, FConfig.WindowDays);

  for Item in Items do
  begin
    if Item.SourceID > MaxID then
      MaxID := Item.SourceID;

    if not FQueue.ShouldEnqueue(Item) then
      Continue;

    Payload := BuildNFCeJson(FEmpresa, Item);
    try
      FQueue.Enqueue(Item, Payload.ToJSON);
    finally
      Payload.Free;
    end;
  end;

  if MaxID > LastCursor then
    FQueue.SetStateInt('last_cursor', MaxID);

  SendPending;
  FLastMessage := Format('Coleta concluida. Registros analisados: %d | Pendentes: %d',
    [Length(Items), FQueue.PendingCount]);
  ConfereLogOperational(FLastMessage);
end;

procedure TConfereSyncEngine.SyncTotal;
var
  Msg: string;
  Items: TArray<TConfereNFCeRecord>;
  Item: TConfereNFCeRecord;
  Payload: TJSONObject;
  MaxID: Integer;
begin
  EnsureEmpresaLoaded;
  if not ValidateApi(Msg) then
    raise Exception.Create('Provisionamento/API falhou: ' + Msg);

  FQueue.ResetFullSync;
  MaxID := 0;
  Items := FSource.LoadChangedSales(0, 3650);
  for Item in Items do
  begin
    if Item.SourceID > MaxID then
      MaxID := Item.SourceID;
    Payload := BuildNFCeJson(FEmpresa, Item);
    try
      FQueue.Enqueue(Item, Payload.ToJSON);
    finally
      Payload.Free;
    end;
  end;

  if MaxID > 0 then
    FQueue.SetStateInt('last_cursor', MaxID);

  while FQueue.PendingCount > 0 do
    SendPending;

  FLastMessage := Format('Sync total concluido. Registros enviados: %d', [Length(Items)]);
  ConfereLogOperational(FLastMessage);
end;

procedure TConfereSyncEngine.SendPending;
var
  Client: TNetHTTPClient;
  Req: TStringStream;
  Resp: IHTTPResponse;
  Pending: TArray<TConfereQueueItem>;
  Batch: TJSONObject;
  Item: TConfereQueueItem;
  Url: string;
begin
  Pending := FQueue.GetPending(100);
  if Length(Pending) = 0 then
    Exit;

  if (Trim(FConfig.ApiBaseUrl) = '') or (Trim(FConfig.ApiToken) = '') then
  begin
    ConfereLogOperational('Fila local mantida: BaseUrl ou Token nao configurados.');
    Exit;
  end;

  Url := BuildLoteUrl;

  Client := TNetHTTPClient.Create(nil);
  try
    Client.ConnectionTimeout := 10000;
    Client.ResponseTimeout := 15000;
    Client.ContentType := 'application/json';
    Client.CustomHeaders['Authorization'] := 'Bearer ' + FConfig.ApiToken;

    Batch := BuildLoteJson(FEmpresa.CNPJ, FConfig.InstalacaoID, Pending);
    try
      Req := TStringStream.Create(Batch.ToJSON, TEncoding.UTF8);
      try
        Resp := Client.Post(Url, Req);
        if (Resp.StatusCode >= 200) and (Resp.StatusCode < 300) then
        begin
          for Item in Pending do
            FQueue.MarkSent(Item.QueueID);
          ConfereLogOperational(Format('Lote enviado com sucesso. Quantidade: %d', [Length(Pending)]));
        end
        else
        begin
          for Item in Pending do
            FQueue.MarkFailed(Item.QueueID, Resp.StatusText);
          ConfereLogError(Format('Falha no envio do lote. HTTP %d %s', [Resp.StatusCode, Resp.StatusText]));
        end;
      finally
        Req.Free;
      end;
    finally
      Batch.Free;
    end;
  except
    on E: Exception do
    begin
      for Item in Pending do
        FQueue.MarkFailed(Item.QueueID, E.Message);
      ConfereLogError('Falha enviando lote HTTPS: ' + E.Message);
    end;
  end;
  Client.Free;
end;

function TConfereSyncEngine.PendingCount: Integer;
begin
  Result := FQueue.PendingCount;
end;

function TConfereSyncEngine.EmpresaResumo: string;
begin
  EnsureEmpresaLoaded;
  Result := Trim(FEmpresa.RazaoSocial);
  if FEmpresa.CNPJ <> '' then
    Result := Result + ' | ' + NormalizeDigits(FEmpresa.CNPJ);
end;

end.
