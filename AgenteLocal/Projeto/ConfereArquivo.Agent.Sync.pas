unit ConfereArquivo.Agent.Sync;

interface

uses
  System.SysUtils, System.Generics.Collections,
  ConfereArquivo.Agent.Config, ConfereArquivo.Agent.Source,
  ConfereArquivo.Agent.SourceNFeSaida, ConfereArquivo.Agent.Queue, ConfereArquivo.Types;

type
  TConfereDocumentKind = (dkNFCe, dkNFeSaida);

  TConfereSyncContext = class
  public
    Kind: TConfereDocumentKind;
    Config: TConfereAgentConfig;
    SourceName: string;
    Queue: TConfereAgentQueue;
    Empresa: TConfereEmpresaInfo;
    EmpresaLoaded: Boolean;
    NFCeSource: TConfereAgentSource;
    NFeSaidaSource: TConfereAgentSourceNFeSaida;
    constructor CreateNFCe(const AConfig: TConfereAgentConfig; const ASourceName: string;
      ASource: TConfereAgentSource; AQueue: TConfereAgentQueue);
    constructor CreateNFeSaida(const AConfig: TConfereAgentConfig; const ASourceName: string;
      ASource: TConfereAgentSourceNFeSaida; AQueue: TConfereAgentQueue);
    destructor Destroy; override;
  end;

  TConfereSyncEngine = class
  private
    FConfig: TConfereAgentConfig;
    FNFCeContexts: TObjectList<TConfereSyncContext>;
    FNFeSaidaContexts: TObjectList<TConfereSyncContext>;
    FLastMessage: string;
    procedure BuildContexts;
    procedure EnsureEmpresaLoaded(AContext: TConfereSyncContext);
    procedure SendPending(AContext: TConfereSyncContext);
    function BuildLoteUrl(const AKind: TConfereDocumentKind): string;
    function BuildQueueDatabasePath(const AKind: TConfereDocumentKind; const ASourcePath: string): string;
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
  System.Net.HttpClient, System.Net.HttpClientComponent,
  ConfereArquivo.Json, ConfereArquivo.Logger;

constructor TConfereSyncContext.CreateNFCe(const AConfig: TConfereAgentConfig;
  const ASourceName: string; ASource: TConfereAgentSource; AQueue: TConfereAgentQueue);
begin
  inherited Create;
  Kind := dkNFCe;
  Config := AConfig;
  SourceName := ASourceName;
  NFCeSource := ASource;
  Queue := AQueue;
end;

constructor TConfereSyncContext.CreateNFeSaida(const AConfig: TConfereAgentConfig;
  const ASourceName: string; ASource: TConfereAgentSourceNFeSaida; AQueue: TConfereAgentQueue);
begin
  inherited Create;
  Kind := dkNFeSaida;
  Config := AConfig;
  SourceName := ASourceName;
  NFeSaidaSource := ASource;
  Queue := AQueue;
end;

destructor TConfereSyncContext.Destroy;
begin
  Queue.Free;
  NFCeSource.Free;
  NFeSaidaSource.Free;
  inherited Destroy;
end;

constructor TConfereSyncEngine.Create(const AConfig: TConfereAgentConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FNFCeContexts := TObjectList<TConfereSyncContext>.Create(True);
  FNFeSaidaContexts := TObjectList<TConfereSyncContext>.Create(True);
  BuildContexts;
end;

destructor TConfereSyncEngine.Destroy;
begin
  FNFeSaidaContexts.Free;
  FNFCeContexts.Free;
  inherited Destroy;
end;

function TConfereSyncEngine.BuildQueueDatabasePath(const AKind: TConfereDocumentKind;
  const ASourcePath: string): string;
var
  Hash, Prefix: string;
begin
  Hash := LowerCase(Copy(THashMD5.GetHashString(LowerCase(Trim(ExpandFileName(ASourcePath)))), 1, 12));
  if AKind = dkNFeSaida then
    Prefix := 'ConfereArquivoQueue_NFeSaida_'
  else
    Prefix := 'ConfereArquivoQueue_NFCe_';
  Result := IncludeTrailingPathDelimiter(FConfig.AppRoot) + 'Config\' + Prefix + Hash + '.sqlite';
end;

procedure TConfereSyncEngine.BuildContexts;
var
  Path: string;
  ContextConfig: TConfereAgentConfig;
  Source: TConfereAgentSource;
  SourceNFe: TConfereAgentSourceNFeSaida;
  Queue: TConfereAgentQueue;
begin
  FNFCeContexts.Clear;
  FNFeSaidaContexts.Clear;

  if FConfig.EnabledNFCe then
    for Path in FConfig.NFCeDatabasePaths do
    begin
      ContextConfig := FConfig;
      ContextConfig.NFCeDatabasePath := Path;
      ContextConfig.SourceDatabasePath := Path;
      ContextConfig.QueueDatabasePath := BuildQueueDatabasePath(dkNFCe, Path);
      Source := TConfereAgentSource.Create(ContextConfig);
      Queue := TConfereAgentQueue.Create(ContextConfig.QueueDatabasePath);
      Queue.EnsureSchema;
      FNFCeContexts.Add(TConfereSyncContext.CreateNFCe(ContextConfig, ExtractFileName(Path), Source, Queue));
    end;

  if FConfig.EnabledNFeSaida then
    for Path in FConfig.NFeSaidaDatabasePaths do
    begin
      ContextConfig := FConfig;
      ContextConfig.NFeSaidaDatabasePath := Path;
      ContextConfig.QueueDatabasePath := BuildQueueDatabasePath(dkNFeSaida, Path);
      SourceNFe := TConfereAgentSourceNFeSaida.Create(ContextConfig);
      Queue := TConfereAgentQueue.Create(ContextConfig.QueueDatabasePath);
      Queue.EnsureSchema;
      FNFeSaidaContexts.Add(TConfereSyncContext.CreateNFeSaida(ContextConfig, ExtractFileName(Path), SourceNFe, Queue));
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
  if (FNFCeContexts.Count = 0) and (FNFeSaidaContexts.Count = 0) then
  begin
    AMessage := 'Nenhuma origem Firebird ativa/configurada.';
    Exit;
  end;

  ValidCount := 0;
  Errors := TStringList.Create;
  try
    for Context in FNFCeContexts do
    begin
      if Context.NFCeSource.Validate(Msg) then
        Inc(ValidCount)
      else
        Errors.Add('NFC-e ' + Context.Config.NFCeDatabasePath + ' -> ' + Msg);
    end;

    for Context in FNFeSaidaContexts do
    begin
      if Context.NFeSaidaSource.Validate(Msg) then
        Inc(ValidCount)
      else
        Errors.Add('NFe Saida ' + Context.Config.NFeSaidaDatabasePath + ' -> ' + Msg);
    end;

    Result := Errors.Count = 0;
    if Result then
      AMessage := Format('Origens Firebird validadas com sucesso. Quantidade: %d', [ValidCount])
    else
      AMessage := 'Falhas encontradas:' + sLineBreak + Trim(Errors.Text);
  finally
    Errors.Free;
  end;
end;

function TConfereSyncEngine.BuildLoteUrl(const AKind: TConfereDocumentKind): string;
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

  if AKind = dkNFeSaida then
    Result := BaseUrl + '/v1/nfe-saida/lote'
  else
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
  if (FNFCeContexts.Count = 0) and (FNFeSaidaContexts.Count = 0) then
  begin
    AMessage := 'Nenhuma origem Firebird ativa/configurada.';
    Exit;
  end;

  Url := BuildLoteUrl(dkNFCe);
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

    for Context in FNFCeContexts do
    begin
      EnsureEmpresaLoaded(Context);
      Body := TJSONObject.Create;
      try
        Body.AddPair('cnpj_empresa', NormalizeDigits(Context.Empresa.CNPJ));
        Body.AddPair('instalacao_id', FConfig.InstalacaoID);
        Body.AddPair('razao_social', Context.Empresa.RazaoSocial);
        Body.AddPair('nome_computador', Context.Empresa.NomeComputador);
        Req := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
        try
          Resp := Client.Post(Url, Req);
          if not ((Resp.StatusCode >= 200) and (Resp.StatusCode < 300)) then
            Errors.Add(Format('NFC-e %s -> HTTP %d %s', [Context.SourceName, Resp.StatusCode, Resp.StatusText]));
        finally
          Req.Free;
        end;
      finally
        Body.Free;
      end;
    end;

    for Context in FNFeSaidaContexts do
    begin
      EnsureEmpresaLoaded(Context);
      Body := TJSONObject.Create;
      try
        Body.AddPair('cnpj_empresa', NormalizeDigits(Context.Empresa.CNPJ));
        Body.AddPair('instalacao_id', FConfig.InstalacaoID);
        Body.AddPair('razao_social', Context.Empresa.RazaoSocial);
        Body.AddPair('nome_computador', Context.Empresa.NomeComputador);
        Req := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
        try
          Resp := Client.Post(Url, Req);
          if not ((Resp.StatusCode >= 200) and (Resp.StatusCode < 300)) then
            Errors.Add(Format('NFe Saida %s -> HTTP %d %s', [Context.SourceName, Resp.StatusCode, Resp.StatusText]));
        finally
          Req.Free;
        end;
      finally
        Body.Free;
      end;
    end;

    Result := Errors.Count = 0;
    if Result then
      AMessage := Format('Servidor validado com sucesso para %d origem(ns).', [FNFCeContexts.Count + FNFeSaidaContexts.Count])
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

  if AContext.Kind = dkNFeSaida then
  begin
    if not AContext.NFeSaidaSource.LoadEmpresa(AContext.Empresa) then
      raise Exception.CreateFmt('Nao foi possivel carregar EMPRESA em %s.', [AContext.SourceName]);
  end
  else
  begin
    if not AContext.NFCeSource.LoadEmpresa(AContext.Empresa) then
      raise Exception.CreateFmt('Nao foi possivel carregar ECF_EMPRESA em %s.', [AContext.SourceName]);
  end;

  AContext.EmpresaLoaded := True;
end;

function TConfereSyncEngine.BuildContextSummary: string;
var
  Context: TConfereSyncContext;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for Context in FNFCeContexts do
    begin
      EnsureEmpresaLoaded(Context);
      Parts.Add('NFC-e: ' + Context.Empresa.RazaoSocial + ' [' + Context.SourceName + ']');
    end;
    for Context in FNFeSaidaContexts do
    begin
      EnsureEmpresaLoaded(Context);
      Parts.Add('NFe Saida: ' + Context.Empresa.RazaoSocial + ' [' + Context.SourceName + ']');
    end;

    if Parts.Count = 0 then
      Result := 'Nenhuma origem configurada'
    else if Parts.Count = 1 then
      Result := Parts[0]
    else
      Result := Format('%d origens ativas | %s', [Parts.Count, StringReplace(Parts.CommaText, ',', ' | ', [rfReplaceAll])]);
  finally
    Parts.Free;
  end;
end;

procedure TConfereSyncEngine.PollNow;
var
  Context: TConfereSyncContext;
  LastCursor, MaxID, TotalAnalyzedNFCe, TotalAnalyzedNFe: Integer;
  NFCeItems: TArray<TConfereNFCeRecord>;
  NFCeItem: TConfereNFCeRecord;
  NFeItems: TArray<TConfereNFeSaidaRecord>;
  NFeItem: TConfereNFeSaidaRecord;
  Payload: TJSONObject;
begin
  TotalAnalyzedNFCe := 0;
  TotalAnalyzedNFe := 0;

  for Context in FNFCeContexts do
  begin
    EnsureEmpresaLoaded(Context);
    LastCursor := Context.Queue.GetStateInt('last_cursor', 0);
    MaxID := LastCursor;
    NFCeItems := Context.NFCeSource.LoadChangedSales(LastCursor, FConfig.WindowDays);
    Inc(TotalAnalyzedNFCe, Length(NFCeItems));

    for NFCeItem in NFCeItems do
    begin
      if NFCeItem.SourceID > MaxID then
        MaxID := NFCeItem.SourceID;

      if Context.NFCeSource.IsSynced(NFCeItem) then
        Continue;

      if not Context.Queue.ShouldEnqueue(NFCeItem.SourceID, NFCeItem.HashIncremento) then
        Continue;

      Payload := BuildNFCeJson(Context.Empresa, NFCeItem);
      try
        Context.Queue.Enqueue(NFCeItem.SourceID, NFCeItem.HashIncremento,
          ConfereStatusToString(NFCeItem.StatusOperacional), Payload.ToJSON);
      finally
        Payload.Free;
      end;
    end;

    if MaxID > LastCursor then
      Context.Queue.SetStateInt('last_cursor', MaxID);

    SendPending(Context);
  end;

  for Context in FNFeSaidaContexts do
  begin
    EnsureEmpresaLoaded(Context);
    LastCursor := Context.Queue.GetStateInt('last_cursor', 0);
    MaxID := LastCursor;
    NFeItems := Context.NFeSaidaSource.LoadChangedNotas(LastCursor, FConfig.WindowDays);
    Inc(TotalAnalyzedNFe, Length(NFeItems));

    for NFeItem in NFeItems do
    begin
      if NFeItem.SourceID > MaxID then
        MaxID := NFeItem.SourceID;

      if Context.NFeSaidaSource.IsSynced(NFeItem) then
        Continue;

      if not Context.Queue.ShouldEnqueue(NFeItem.SourceID, NFeItem.HashIncremento) then
        Continue;

      Payload := BuildNFeSaidaJson(Context.Empresa, NFeItem);
      try
        Context.Queue.Enqueue(NFeItem.SourceID, NFeItem.HashIncremento,
          NFeItem.StatusOperacional, Payload.ToJSON);
      finally
        Payload.Free;
      end;
    end;

    if MaxID > LastCursor then
      Context.Queue.SetStateInt('last_cursor', MaxID);

    SendPending(Context);
  end;

  FLastMessage := Format('Coleta concluida. NFC-e: %d | NFe Saida: %d | Pendentes: %d',
    [TotalAnalyzedNFCe, TotalAnalyzedNFe, PendingCount]);
  ConfereLogOperational(FLastMessage);
end;

procedure TConfereSyncEngine.SyncTotal;
var
  Msg: string;
  Context: TConfereSyncContext;
  NFCeItems: TArray<TConfereNFCeRecord>;
  NFCeItem: TConfereNFCeRecord;
  NFeItems: TArray<TConfereNFeSaidaRecord>;
  NFeItem: TConfereNFeSaidaRecord;
  Payload: TJSONObject;
  MaxID, TotalLoadedNFCe, TotalLoadedNFe: Integer;
begin
  if not ValidateApi(Msg) then
    raise Exception.Create('Provisionamento/API falhou: ' + Msg);

  TotalLoadedNFCe := 0;
  TotalLoadedNFe := 0;

  for Context in FNFCeContexts do
  begin
    EnsureEmpresaLoaded(Context);
    Context.Queue.ResetFullSync;
    MaxID := 0;
    NFCeItems := Context.NFCeSource.LoadChangedSales(0, 3650);
    Inc(TotalLoadedNFCe, Length(NFCeItems));

    for NFCeItem in NFCeItems do
    begin
      if NFCeItem.SourceID > MaxID then
        MaxID := NFCeItem.SourceID;

      if Context.NFCeSource.IsSynced(NFCeItem) then
        Continue;

      Payload := BuildNFCeJson(Context.Empresa, NFCeItem);
      try
        Context.Queue.Enqueue(NFCeItem.SourceID, NFCeItem.HashIncremento,
          ConfereStatusToString(NFCeItem.StatusOperacional), Payload.ToJSON);
      finally
        Payload.Free;
      end;
    end;

    if MaxID > 0 then
      Context.Queue.SetStateInt('last_cursor', MaxID);

    while Context.Queue.PendingCount > 0 do
      SendPending(Context);
  end;

  for Context in FNFeSaidaContexts do
  begin
    EnsureEmpresaLoaded(Context);
    Context.Queue.ResetFullSync;
    MaxID := 0;
    NFeItems := Context.NFeSaidaSource.LoadChangedNotas(0, 3650);
    Inc(TotalLoadedNFe, Length(NFeItems));

    for NFeItem in NFeItems do
    begin
      if NFeItem.SourceID > MaxID then
        MaxID := NFeItem.SourceID;

      if Context.NFeSaidaSource.IsSynced(NFeItem) then
        Continue;

      Payload := BuildNFeSaidaJson(Context.Empresa, NFeItem);
      try
        Context.Queue.Enqueue(NFeItem.SourceID, NFeItem.HashIncremento,
          NFeItem.StatusOperacional, Payload.ToJSON);
      finally
        Payload.Free;
      end;
    end;

    if MaxID > 0 then
      Context.Queue.SetStateInt('last_cursor', MaxID);

    while Context.Queue.PendingCount > 0 do
      SendPending(Context);
  end;

  FLastMessage := Format('Sync total concluido. NFC-e: %d | NFe Saida: %d',
    [TotalLoadedNFCe, TotalLoadedNFe]);
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
  Url, KindName: string;
begin
  Pending := AContext.Queue.GetPending(100);
  if Length(Pending) = 0 then
    Exit;

  if (Trim(FConfig.ApiBaseUrl) = '') or (Trim(FConfig.ApiToken) = '') then
  begin
    ConfereLogOperational('Fila local mantida: BaseUrl ou Token nao configurados.');
    Exit;
  end;

  Url := BuildLoteUrl(AContext.Kind);
  if AContext.Kind = dkNFeSaida then
    KindName := 'NFe Saida'
  else
    KindName := 'NFC-e';

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
            if AContext.Kind = dkNFeSaida then
              AContext.NFeSaidaSource.MarkAsSynced(Item.SourceID, Item.HashIncremento, '')
            else
              AContext.NFCeSource.MarkAsSynced(Item.SourceID, Item.HashIncremento, '');
          end;
          ConfereLogOperational(Format('Lote enviado com sucesso. Tipo: %s | Banco: %s | Quantidade: %d',
            [KindName, AContext.SourceName, Length(Pending)]));
        end
        else
        begin
          for Item in Pending do
            AContext.Queue.MarkFailed(Item.QueueID, Resp.StatusText);
          ConfereLogError(Format('Falha no envio do lote. Tipo: %s | Banco: %s | HTTP %d %s',
            [KindName, AContext.SourceName, Resp.StatusCode, Resp.StatusText]));
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
      ConfereLogError(Format('Falha enviando lote HTTPS. Tipo: %s | Banco: %s | %s',
        [KindName, AContext.SourceName, E.Message]));
    end;
  end;
  Client.Free;
end;

function TConfereSyncEngine.PendingCount: Integer;
var
  Context: TConfereSyncContext;
begin
  Result := 0;
  for Context in FNFCeContexts do
    Inc(Result, Context.Queue.PendingCount);
  for Context in FNFeSaidaContexts do
    Inc(Result, Context.Queue.PendingCount);
end;

function TConfereSyncEngine.EmpresaResumo: string;
begin
  Result := BuildContextSummary;
end;

end.
