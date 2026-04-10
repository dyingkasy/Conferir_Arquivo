unit ConfereArquivo.Office.Client;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TConfereResumo = record
    QuantidadeTotal: Integer;
    QuantidadeAutorizada: Integer;
    QuantidadeContingencia: Integer;
    QuantidadePendente: Integer;
    QuantidadeRejeitada: Integer;
    QuantidadeCancelada: Integer;
    ValorTotalDocumento: Currency;
    ValorTotalContingencia: Currency;
    ValorTotalPendente: Currency;
  end;

  TConfereNotaConsulta = record
    SourceID: Integer;
    InstalacaoID: string;
    DataVenda: string;
    HoraVenda: string;
    NumeroNFCe: string;
    SerieNFCe: string;
    ChaveAcesso: string;
    Protocolo: string;
    StatusOperacional: string;
    StatusErro: string;
    NFCeOffline: string;
    NFCeCancelada: string;
    ValorDocumento: Currency;
    NomeCliente: string;
    DocumentoCliente: string;
  end;

  TConfereOfficeClient = class
  private
    FBaseUrl: string;
    FToken: string;
    function BuildUrl(const APath: string): string;
    function GetJson(const AUrl: string): string;
    function JsonToCurrency(const AValue: string): Currency;
  public
    constructor Create(const ABaseUrl, AToken: string);
    function Health: string;
    function LoadResumo(const ACNPJ: string; ADias: Integer): TConfereResumo;
    function LoadLista(const ACNPJ, AStatus, ADataInicial, ADataFinal: string; ALimit: Integer): TArray<TConfereNotaConsulta>;
  end;

implementation

uses
  System.JSON, System.StrUtils, System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient;

constructor TConfereOfficeClient.Create(const ABaseUrl, AToken: string);
begin
  inherited Create;
  FBaseUrl := Trim(ABaseUrl);
  FToken := Trim(AToken);
end;

function TConfereOfficeClient.BuildUrl(const APath: string): string;
var
  Base: string;
begin
  Base := StringReplace(FBaseUrl, '\', '/', [rfReplaceAll]);
  while Base.EndsWith('/') do
    Delete(Base, Length(Base), 1);
  Result := Base + APath;
end;

function TConfereOfficeClient.GetJson(const AUrl: string): string;
var
  Client: TNetHTTPClient;
  Resp: IHTTPResponse;
begin
  Client := TNetHTTPClient.Create(nil);
  try
    Client.ConnectionTimeout := 10000;
    Client.ResponseTimeout := 20000;
    Client.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    Resp := Client.Get(AUrl);
    if (Resp.StatusCode < 200) or (Resp.StatusCode >= 300) then
      raise Exception.CreateFmt('HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
    Result := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Client.Free;
  end;
end;

function TConfereOfficeClient.JsonToCurrency(const AValue: string): Currency;
begin
  Result := StrToCurrDef(StringReplace(Trim(AValue), '.', ',', [rfReplaceAll]), 0);
end;

function TConfereOfficeClient.Health: string;
begin
  Result := GetJson(BuildUrl('/health'));
end;

function TConfereOfficeClient.LoadResumo(const ACNPJ: string; ADias: Integer): TConfereResumo;
var
  Json: TJSONObject;
  Raw: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Raw := GetJson(BuildUrl('/api/v1/nfce/resumo?cnpj_empresa=' + ACNPJ + '&dias=' + IntToStr(ADias)));
  Json := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  try
    if not Assigned(Json) then
      raise Exception.Create('JSON invalido no resumo.');
    Result.QuantidadeTotal := Json.GetValue<Integer>('quantidade_total', 0);
    Result.QuantidadeAutorizada := Json.GetValue<Integer>('quantidade_autorizada', 0);
    Result.QuantidadeContingencia := Json.GetValue<Integer>('quantidade_contingencia', 0);
    Result.QuantidadePendente := Json.GetValue<Integer>('quantidade_pendente', 0);
    Result.QuantidadeRejeitada := Json.GetValue<Integer>('quantidade_rejeitada', 0);
    Result.QuantidadeCancelada := Json.GetValue<Integer>('quantidade_cancelada', 0);
    Result.ValorTotalDocumento := JsonToCurrency(Json.GetValue('valor_total_documento').Value);
    Result.ValorTotalContingencia := JsonToCurrency(Json.GetValue('valor_total_contingencia').Value);
    Result.ValorTotalPendente := JsonToCurrency(Json.GetValue('valor_total_pendente').Value);
  finally
    Json.Free;
  end;
end;

function TConfereOfficeClient.LoadLista(const ACNPJ, AStatus, ADataInicial,
  ADataFinal: string; ALimit: Integer): TArray<TConfereNotaConsulta>;
var
  Url, Raw: string;
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: TConfereNotaConsulta;
  List: TList<TConfereNotaConsulta>;
begin
  Url := '/api/v1/nfce/lista?cnpj_empresa=' + ACNPJ + '&limit=' + IntToStr(ALimit);
  if Trim(AStatus) <> '' then
    Url := Url + '&status_operacional=' + AStatus;
  if Trim(ADataInicial) <> '' then
    Url := Url + '&data_inicial=' + ADataInicial;
  if Trim(ADataFinal) <> '' then
    Url := Url + '&data_final=' + ADataFinal;

  Raw := GetJson(BuildUrl(Url));
  Json := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  List := TList<TConfereNotaConsulta>.Create;
  try
    if not Assigned(Json) then
      raise Exception.Create('JSON invalido na lista.');
    Arr := Json.GetValue<TJSONArray>('items');
    if Assigned(Arr) then
      for I := 0 to Arr.Count - 1 do
      begin
        ItemObj := Arr.Items[I] as TJSONObject;
        FillChar(Item, SizeOf(Item), 0);
        Item.SourceID := ItemObj.GetValue<Integer>('source_id', 0);
        Item.InstalacaoID := ItemObj.GetValue<string>('instalacao_id', '');
        Item.DataVenda := ItemObj.GetValue<string>('data_venda', '');
        Item.HoraVenda := ItemObj.GetValue<string>('hora_venda', '');
        Item.NumeroNFCe := ItemObj.GetValue<string>('num_nfce', '');
        Item.SerieNFCe := ItemObj.GetValue<string>('serie_nfce', '');
        Item.ChaveAcesso := ItemObj.GetValue<string>('chave_acesso', '');
        Item.Protocolo := ItemObj.GetValue<string>('protocolo', '');
        Item.StatusOperacional := ItemObj.GetValue<string>('status_operacional', '');
        Item.StatusErro := ItemObj.GetValue<string>('status_erro', '');
        Item.NFCeOffline := ItemObj.GetValue<string>('nfce_offline', '');
        Item.NFCeCancelada := ItemObj.GetValue<string>('nfce_cancelada', '');
        if Assigned(ItemObj.GetValue('valor_documento')) then
          Item.ValorDocumento := JsonToCurrency(ItemObj.GetValue('valor_documento').Value);
        Item.NomeCliente := ItemObj.GetValue<string>('nome_cliente', '');
        Item.DocumentoCliente := ItemObj.GetValue<string>('documento_cliente', '');
        List.Add(Item);
      end;
    Result := List.ToArray;
  finally
    List.Free;
    Json.Free;
  end;
end;

end.
