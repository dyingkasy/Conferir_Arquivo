unit ConfereArquivo.Agent.Sync;

interface

uses
  System.SysUtils, System.Generics.Collections,
  ConfereArquivo.Agent.Config, ConfereArquivo.Agent.Source,
  ConfereArquivo.Agent.Queue, ConfereArquivo.Types;

type
  TConfereSyncContext = class
  public
    Config: TConfereAgentConfig;
    SourceName: string;
    Source: TConfereAgentSource;
    Queue: TConfereAgentQueue;
    Empresa: TConfereEmpresaInfo;
    EmpresaLoaded: Boolean;
    constructor Create(const AConfig: TConfereAgentConfig; const ASourceName: string;
      ASource: TConfereAgentSource; AQueue: TConfereAgentQueue);
    destructor Destroy; override;
  end;

  TConfereSyncEngine = class
  private
    FConfig: TConfereAgentConfig;
    FContexts: TObjectList<TConfereSyncContext>;
    FLastMessage: string;
    procedure BuildContexts;
    procedure EnsureEmpresaLoaded(AContext: TConfereSyncContext);
    procedure SendPending(AContext: TConfereSyncContext);
    function BuildLoteUrl: string;
    function BuildQueueDatabasePath(const ASourcePath: string): string;
    function BuildContextSummary: string;
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
  System.Classes, System.JSON, System.StrUtils, System.Hash,
  System.Net.URLClient, System.Net.HttpClient, System.Net.HttpClientComponent,
  ConfereArquivo.Json, ConfereArquivo.Logger;

constructor TConfereSyncContext.Create(const AConfig: TConfereAgentConfig;
  const ASourceName: string; ASource: TConfereAgentSource; AQueue: TConfereAgentQueue);
begin
  inherited Create;
  Config := AConfig;
  SourceName := ASourceName;
  Source := ASource;
  Queue := AQueue;
  EmpresaLoaded := False;
end;

destructor TConfereSyncContext.Destroy;
begin
  Queue.Free;
  Source.Free;
  inherited Destroy;
end;

constructor TConfereSyncEngine.Create(const AConfig: TConfereAgentConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FContexts := TObjectList<TConfereSyncContext>.Create(True);
  BuildContexts;
end;

destructor TConfereSyncEngine.Destroy;
begin
  FContexts.Free;
  inherited Destroy;
end;

function TConfereSyncEngine.BuildQueueDatabasePath(const ASourcePath: string): string;
var
  Hash: string;
begin
  Hash := LowerCase(Copy(THashMD5.GetHashString(LowerCase(Trim(ExpandFileName(ASourcePath)))), 1, 12));
  Result := IncludeTrailingPathDelimiter(FConfig.AppRoot) + 'Config\ConfereArquivoQueue_' + Hash + '.sqlite';
end;

procedure TConfereSyncEngine.BuildContexts;
var
  Path: string;
  ContextConfig: TConfereAgentConfig;
  Source: TConfereAgentSource;
  Queue: TConfereAgentQueue;
begin
  FContexts.Clear;
  for Path in FConfig.SourceDatabasePaths do
  begin
    ContextConfig := FConfig;
    ContextConfig.SourceDatabasePath := Path;
    ContextConfig.QueueDatabasePath := BuildQueueDatabasePath(Path);
    Source := TConfereAgentSource.Create(ContextConfig);
    Queue := TConfereAgentQueue.Create(ContextConfig.QueueDatabasePath);
    Queue.EnsureSchema;
    FContexts.Add(TConfereSyncContext.Create(ContextConfig, ExtractFileName(Path), Source, Queue));
  end;
end;

function TConfereSyncEngine.Validate(out AMessage: string): Boolean;
var
  Context: TConfereSyncContext;
  Msg: string;
  ValidCount: Integer;
  Errors: TStringList;
begin
  Result := False;
  AMessage := '';
  if FContexts.Count = 0 then
  begin
    AMessage := 'Nenhum banco PAFECF configurado.';
    Exit;
  end;

  ValidCount := 0;
  Errors := TStringList.Create;
  try
    for Context in FContexts do
    begin
      if Context.Source.Validate(Msg) then
        Inc(ValidCount)
      else
        Errors.Add(Context.Config.SourceDatabasePath + ' -> ' + Msg);
    end;

    Result := Errors.Count = 0;
    if Result then
      AMessage := Format('Bancos PAFECF validados com sucesso. Quantidade: %d', [ValidCount])
    else
      AMessage := 'Falhas encontradas:' + sLineBreak + Trim(Errors.Text);
  finally
    Errors.Free;
  end;
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
  Context: TConfereSyncContext;
  Errors: TStringList;
begin
  Result := False;
  AMessage := '';
  if FContexts.Count = 0 then
  begin
    AMessage := 'Nenhum banco PAFECF configurado.';
    Exit;
  end;

  Url := BuildLoteUrl;
  if Url = '' then
  begin
    AMessage := 'BaseUrl nao configurada.';
    Exit;
  end;

  Url := StringReplace(Url, '/nfce/lote', '/agente/config-check', [rfIgnoreCase]);

  Client := TNetHTTPClient.Create(nil);
  Errors := TStringList.Create;
  try
    Client.ConnectionTimeout := 8000;
    Client.ResponseTimeout := 12000;
    Client.ContentType := 'application/json';
    Client.CustomHeaders['Authorization'] := 'Bearer ' + Trim(FConfig.ApiToken);

    for Context in FContexts do
    begin
      EnsureEmpresaLoaded(Context);
      Body := TJSONObject.Create;
      try
        Body.AddPair('cnpj_empresa', NormalizeDigits(Context.Empresa.CNPJ));
        Body.AddPair('instalacao_id', FConfig.InstalacaoID);
        Body.AddPair('razao_social', Context.Empresa.RazaoSocial);
        Req := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
        try
          Resp := Client.Post(Url, Req);
          if not ((Resp.StatusCode >= 200) and (Resp.StatusCode < 300)) then
            Errors.Add(Format('%s -> HTTP %d %s', [Context.SourceName, Resp.StatusCode, Resp.StatusText]));
        finally
          Req.Free;
        end;
      finally
        Body.Free;
      end;
    end;

    Result := Errors.Count = 0;
    if Result then
      AMessage := Format('Servidor validado com sucesso para %d banco(s).', [FContexts.Count])
    else
      AMessage := Trim(Errors.Text);
  except
    on E: Exception do
      AMessage := E.Message;
  end;
  Errors.Free;
  Client.Free;
end;

procedure TConfereSyncEngine.EnsureEmpresaLoaded(AContext: TConfereSyncContext);
begin
  if AContext.EmpresaLoaded and (AContext.Empresa.CNPJ <> '') then
    Exit;

  if not AContext.Source.LoadEmpresa(AContext.Empresa) then
    raise Exception.CreateFmt('Nao foi possivel carregar ECF_EMPRESA em %s.', [AContext.SourceName]);

  AContext.EmpresaLoaded := True;
end;

function TConfereSyncEngine.BuildContextSummary: string;
var
  Context: TConfereSyncContext;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for Context in FContexts do
    begin
      EnsureEmpresaLoaded(Context);
      if Context.Empresa.RazaoSocial <> '' then
        Parts.Add(Context.Empresa.RazaoSocial + ' [' + Context.SourceName + ']')
      else
        Parts.Add(Context.SourceName);
    end;

    if Parts.Count = 0 then
      Result := 'Nenhum banco configurado'
    else if Parts.Count = 1 then
      Result := Parts[0]
    else
      Result := Format('%d bancos ativos | %s', [Parts.Count, StringReplace(Parts.CommaText, ',', ' | ', [rfReplaceAll])]);
  finally
    Parts.Free;
  end;
end;

procedure TConfereSyncEngine.PollNow;
var
  Context: TConfereSyncContext;
  LastCursor, MaxID: Integer;
  Items: TArray<TConfereNFCeRecord>;
  Item: TConfereNFCeRecord;
  Payload: TJSONObject;
  TotalAnalyzed: Integer;
begin
  TotalAnalyzed := 0;
  for Context in FContexts do
  begin
    EnsureEmpresaLoaded(Context);

    LastCursor := Context.Queue.GetStateInt('last_cursor', 0);
    MaxID := LastCursor;
    Items := Context.Source.LoadChangedSales(LastCursor, FConfig.WindowDays);
    Inc(TotalAnalyzed, Length(Items));

    for Item in Items do
    begin
      if Item.SourceID > MaxID then
        MaxID := Item.SourceID;

      if Context.Source.IsSynced(Item) then
        Continue;

      if not Context.Queue.ShouldEnqueue(Item) then
        Continue;

      Payload := BuildNFCeJson(Context.Empresa, Item);
      try
        Context.Queue.Enqueue(Item, Payload.ToJSON);
      finally
        Payload.Free;
      end;
    end;

    if MaxID > LastCursor then
      Context.Queue.SetStateInt('last_cursor', MaxID);

    SendPending(Context);
  end;

  FLastMessage := Format('Coleta NFC-e concluida. Bancos: %d | Registros analisados: %d | Pendentes: %d',
    [FContexts.Count, TotalAnalyzed, PendingCount]);
  ConfereLogOperational(FLastMessage);
end;

procedure TConfereSyncEngine.SyncTotal;
var
  Msg: string;
  Context: TConfereSyncContext;
  Items: TArray<TConfereNFCeRecord>;
  Item: TConfereNFCeRecord;
  Payload: TJSONObject;
  MaxID, TotalLoaded: Integer;
begin
  if not ValidateApi(Msg) then
    raise Exception.Create('Provisionamento/API falhou: ' + Msg);

  TotalLoaded := 0;
  for Context in FContexts do
  begin
    EnsureEmpresaLoaded(Context);
    Context.Queue.ResetFullSync;
    MaxID := 0;
    Items := Context.Source.LoadChangedSales(0, 3650);
    Inc(TotalLoaded, Length(Items));

    for Item in Items do
    begin
      if Item.SourceID > MaxID then
        MaxID := Item.SourceID;

      if Context.Source.IsSynced(Item) then
        Continue;

      Payload := BuildNFCeJson(Context.Empresa, Item);
      try
        Context.Queue.Enqueue(Item, Payload.ToJSON);
      finally
        Payload.Free;
      end;
    end;

    if MaxID > 0 then
      Context.Queue.SetStateInt('last_cursor', MaxID);

    while Context.Queue.PendingCount > 0 do
      SendPending(Context);
  end;

  FLastMessage := Format('Sync total NFC-e concluido. Bancos: %d | Registros avaliados: %d',
    [FContexts.Count, TotalLoaded]);
  ConfereLogOperational(FLastMessage);
end;

procedure TConfereSyncEngine.SendPending(AContext: TConfereSyncContext);
var
  Client: TNetHTTPClient;
  Req: TStringStream;
  Resp: IHTTPResponse;
  Pending: TArray<TConfereQueueItem>;
  Batch: TJSONObject;
  Item: TConfereQueueItem;
  Url: string;
begin
  Pending := AContext.Queue.GetPending(100);
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

    Batch := BuildLoteJson(AContext.Empresa.CNPJ, FConfig.InstalacaoID, Pending);
    try
      Req := TStringStream.Create(Batch.ToJSON, TEncoding.UTF8);
      try
        Resp := Client.Post(Url, Req);
        if (Resp.StatusCode >= 200) and (Resp.StatusCode < 300) then
        begin
          for Item in Pending do
          begin
            AContext.Queue.MarkSent(Item.QueueID);
            AContext.Source.MarkAsSynced(Item.SourceID, Item.HashIncremento, '');
          end;
          ConfereLogOperational(Format('Lote enviado com sucesso. Banco: %s | Quantidade: %d',
            [AContext.SourceName, Length(Pending)]));
        end
        else
        begin
          for Item in Pending do
            AContext.Queue.MarkFailed(Item.QueueID, Resp.StatusText);
          ConfereLogError(Format('Falha no envio do lote. Banco: %s | HTTP %d %s',
            [AContext.SourceName, Resp.StatusCode, Resp.StatusText]));
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
        AContext.Queue.MarkFailed(Item.QueueID, E.Message);
      ConfereLogError(Format('Falha enviando lote HTTPS. Banco: %s | %s',
        [AContext.SourceName, E.Message]));
    end;
  end;
  Client.Free;
end;

function TConfereSyncEngine.PendingCount: Integer;
var
  Context: TConfereSyncContext;
begin
  Result := 0;
  for Context in FContexts do
    Inc(Result, Context.Queue.PendingCount);
end;

function TConfereSyncEngine.EmpresaResumo: string;
begin
  Result := BuildContextSummary;
end;

end.
