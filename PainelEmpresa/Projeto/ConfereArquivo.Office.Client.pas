unit ConfereArquivo.Office.Client;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TConfereFiltroValor = record
    Valor: string;
  end;

  TConfereResumo = record
    QuantidadeTotal: Integer;
    QuantidadeTransmitida: Integer;
    QuantidadeContingencia: Integer;
    QuantidadeSemFiscal: Integer;
    QuantidadeErro: Integer;
    ValorTotalDocumento: Currency;
    ValorTotalTransmitido: Currency;
    ValorTotalContingencia: Currency;
    ValorTotalSemFiscal: Currency;
    ValorTotalErro: Currency;
    ValorBaseICMS: Currency;
    ValorICMS: Currency;
    ValorPIS: Currency;
    ValorCOFINS: Currency;
    ValorImpostoFederal: Currency;
    ValorImpostoEstadual: Currency;
  end;

  TConfereNotaConsulta = record
    SourceID: Integer;
    InstalacaoID: string;
    NomeComputador: string;
    GrupoConferencia: string;
    DataVenda: string;
    HoraVenda: string;
    DataTransmissao: string;
    NumeroNFCe: string;
    SerieNFCe: string;
    ChaveAcesso: string;
    Protocolo: string;
    StatusOperacional: string;
    StatusErro: string;
    NFCeOffline: string;
    NFCeCancelada: string;
    ValorDocumento: Currency;
    BaseICMS: Currency;
    ICMS: Currency;
    PIS: Currency;
    COFINS: Currency;
    ImpostoFederal: Currency;
    ImpostoEstadual: Currency;
    NomeCliente: string;
    DocumentoCliente: string;
  end;

  TConfereEmpresaDisponivel = record
    CNPJ: string;
    RazaoSocial: string;
    QuantidadeXML: Integer;
    UltimaAtualizacao: string;
  end;

  TConfereOfficeClient = class
  private
    FBaseUrl: string;
    FToken: string;
    function NormalizeDocType(const ADocType: string): string;
    function DocApiBase(const ADocType: string): string;
    function BuildUrl(const APath: string): string;
    function GetJson(const AUrl: string): string;
    function JsonToCurrency(const AValue: string): Currency;
  public
    constructor Create(const ABaseUrl, AToken: string);
    function Health: string;
    function LoadEmpresas: TArray<TConfereEmpresaDisponivel>;
    function LoadSeries(const ADocType, ACNPJ: string): TArray<TConfereFiltroValor>;
    function LoadComputadores(const ADocType, ACNPJ: string): TArray<TConfereFiltroValor>;
    function LoadResumo(const ADocType, ACNPJ, ADataInicial, ADataFinal, ASerie, ANomeComputador, ANumeroDocumento: string; ADias: Integer): TConfereResumo;
    function LoadLista(const ADocType, ACNPJ, AStatus, ADataInicial, ADataFinal, ASerie, ANomeComputador, ANumeroDocumento: string; ALimit: Integer): TArray<TConfereNotaConsulta>;
  end;

implementation

uses
  System.JSON, System.StrUtils, System.NetEncoding, System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient;

constructor TConfereOfficeClient.Create(const ABaseUrl, AToken: string);
begin
  inherited Create;
  FBaseUrl := Trim(ABaseUrl);
  FToken := Trim(AToken);
end;

function TConfereOfficeClient.NormalizeDocType(const ADocType: string): string;
begin
  Result := UpperCase(Trim(ADocType));
  if Result = '' then
    Result := 'NFCE';
end;

function TConfereOfficeClient.DocApiBase(const ADocType: string): string;
begin
  if NormalizeDocType(ADocType) = 'NFE_SAIDA' then
    Result := '/api/v1/nfe-saida'
  else if NormalizeDocType(ADocType) = 'NFE_ENTRADA' then
    Result := '/api/v1/nfe-entrada'
  else
    Result := '/api/v1/nfce';
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

function TConfereOfficeClient.LoadEmpresas: TArray<TConfereEmpresaDisponivel>;
var
  Raw: string;
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: TConfereEmpresaDisponivel;
  List: TList<TConfereEmpresaDisponivel>;
begin
  Raw := GetJson(BuildUrl('/api/v1/empresas'));
  Json := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  List := TList<TConfereEmpresaDisponivel>.Create;
  try
    if not Assigned(Json) then
      raise Exception.Create('JSON invalido na lista de empresas.');
    Arr := Json.GetValue<TJSONArray>('items');
    if Assigned(Arr) then
      for I := 0 to Arr.Count - 1 do
      begin
        ItemObj := Arr.Items[I] as TJSONObject;
        FillChar(Item, SizeOf(Item), 0);
        Item.CNPJ := ItemObj.GetValue<string>('cnpj', '');
        Item.RazaoSocial := ItemObj.GetValue<string>('razao_social', '');
        Item.QuantidadeXML := ItemObj.GetValue<Integer>('quantidade_xml', 0);
        Item.UltimaAtualizacao := ItemObj.GetValue<string>('ultima_atualizacao', '');
        List.Add(Item);
      end;
    Result := List.ToArray;
  finally
    List.Free;
    Json.Free;
  end;
end;

function TConfereOfficeClient.LoadSeries(const ADocType, ACNPJ: string): TArray<TConfereFiltroValor>;
var
  Raw: string;
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: TConfereFiltroValor;
  List: TList<TConfereFiltroValor>;
begin
  if (NormalizeDocType(ADocType) = 'NFE_SAIDA') or (NormalizeDocType(ADocType) = 'NFE_ENTRADA') then
    Raw := GetJson(BuildUrl(DocApiBase(ADocType) + '/series?cnpj_empresa=' + ACNPJ))
  else
    Raw := GetJson(BuildUrl(DocApiBase(ADocType) + '/series?cnpj_empresa=' + ACNPJ));
  Json := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  List := TList<TConfereFiltroValor>.Create;
  try
    if not Assigned(Json) then
      raise Exception.Create('JSON invalido na lista de series.');
    Arr := Json.GetValue<TJSONArray>('items');
    if Assigned(Arr) then
      for I := 0 to Arr.Count - 1 do
      begin
        ItemObj := Arr.Items[I] as TJSONObject;
        FillChar(Item, SizeOf(Item), 0);
        Item.Valor := ItemObj.GetValue<string>('valor', '');
        List.Add(Item);
      end;
    Result := List.ToArray;
  finally
    List.Free;
    Json.Free;
  end;
end;

function TConfereOfficeClient.LoadComputadores(const ADocType, ACNPJ: string): TArray<TConfereFiltroValor>;
var
  Raw: string;
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: TConfereFiltroValor;
  List: TList<TConfereFiltroValor>;
begin
  Raw := GetJson(BuildUrl(DocApiBase(ADocType) + '/computadores?cnpj_empresa=' + ACNPJ));
  Json := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  List := TList<TConfereFiltroValor>.Create;
  try
    if not Assigned(Json) then
      raise Exception.Create('JSON invalido na lista de computadores.');
    Arr := Json.GetValue<TJSONArray>('items');
    if Assigned(Arr) then
      for I := 0 to Arr.Count - 1 do
      begin
        ItemObj := Arr.Items[I] as TJSONObject;
        FillChar(Item, SizeOf(Item), 0);
        Item.Valor := ItemObj.GetValue<string>('valor', '');
        List.Add(Item);
      end;
    Result := List.ToArray;
  finally
    List.Free;
    Json.Free;
  end;
end;

function TConfereOfficeClient.LoadResumo(const ADocType, ACNPJ, ADataInicial, ADataFinal,
  ASerie, ANomeComputador, ANumeroDocumento: string; ADias: Integer): TConfereResumo;
var
  Json: TJSONObject;
  Raw: string;
  Url: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Url := DocApiBase(ADocType) + '/resumo?cnpj_empresa=' + ACNPJ;
  if (Trim(ADataInicial) <> '') and (Trim(ADataFinal) <> '') then
    Url := Url + '&data_inicial=' + ADataInicial + '&data_final=' + ADataFinal
  else
    Url := Url + '&dias=' + IntToStr(ADias);
  if Trim(ASerie) <> '' then
  begin
    if NormalizeDocType(ADocType) = 'NFE_SAIDA' then
      Url := Url + '&serie_nota_fiscal=' + ASerie
    else if NormalizeDocType(ADocType) = 'NFE_ENTRADA' then
      Url := Url + '&serie_nota=' + ASerie
    else
      Url := Url + '&serie_nfce=' + ASerie;
  end;
  if Trim(ANomeComputador) <> '' then
    Url := Url + '&nome_computador=' + TNetEncoding.URL.Encode(ANomeComputador);
  if Trim(ANumeroDocumento) <> '' then
    Url := Url + '&numero_documento=' + TNetEncoding.URL.Encode(Trim(ANumeroDocumento));

  Raw := GetJson(BuildUrl(Url));
  Json := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  try
    if not Assigned(Json) then
      raise Exception.Create('JSON invalido no resumo.');
    Result.QuantidadeTotal := Json.GetValue<Integer>('quantidade_total', 0);
    Result.QuantidadeTransmitida := Json.GetValue<Integer>('quantidade_transmitida', 0);
    Result.QuantidadeContingencia := Json.GetValue<Integer>('quantidade_contingencia', 0);
    Result.QuantidadeSemFiscal := Json.GetValue<Integer>('quantidade_sem_fiscal', 0);
    Result.QuantidadeErro := Json.GetValue<Integer>('quantidade_erro', 0);
    Result.ValorTotalDocumento := JsonToCurrency(Json.GetValue('valor_total_documento').Value);
    Result.ValorTotalTransmitido := JsonToCurrency(Json.GetValue('valor_total_transmitido').Value);
    Result.ValorTotalContingencia := JsonToCurrency(Json.GetValue('valor_total_contingencia').Value);
    Result.ValorTotalSemFiscal := JsonToCurrency(Json.GetValue('valor_total_sem_fiscal').Value);
    Result.ValorTotalErro := JsonToCurrency(Json.GetValue('valor_total_erro').Value);
    Result.ValorBaseICMS := JsonToCurrency(Json.GetValue('valor_base_icms').Value);
    Result.ValorICMS := JsonToCurrency(Json.GetValue('valor_icms').Value);
    Result.ValorPIS := JsonToCurrency(Json.GetValue('valor_pis').Value);
    Result.ValorCOFINS := JsonToCurrency(Json.GetValue('valor_cofins').Value);
    Result.ValorImpostoFederal := JsonToCurrency(Json.GetValue('valor_imposto_federal').Value);
    Result.ValorImpostoEstadual := JsonToCurrency(Json.GetValue('valor_imposto_estadual').Value);
  finally
    Json.Free;
  end;
end;

function TConfereOfficeClient.LoadLista(const ADocType, ACNPJ, AStatus, ADataInicial,
  ADataFinal, ASerie, ANomeComputador, ANumeroDocumento: string; ALimit: Integer): TArray<TConfereNotaConsulta>;
var
  Url, Raw: string;
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: TConfereNotaConsulta;
  List: TList<TConfereNotaConsulta>;
begin
  Url := DocApiBase(ADocType) + '/lista?cnpj_empresa=' + ACNPJ + '&limit=' + IntToStr(ALimit);
  if Trim(AStatus) <> '' then
    Url := Url + '&status_operacional=' + AStatus;
  if Trim(ADataInicial) <> '' then
    Url := Url + '&data_inicial=' + ADataInicial;
  if Trim(ADataFinal) <> '' then
    Url := Url + '&data_final=' + ADataFinal;
  if Trim(ASerie) <> '' then
  begin
    if NormalizeDocType(ADocType) = 'NFE_SAIDA' then
      Url := Url + '&serie_nota_fiscal=' + ASerie
    else if NormalizeDocType(ADocType) = 'NFE_ENTRADA' then
      Url := Url + '&serie_nota=' + ASerie
    else
      Url := Url + '&serie_nfce=' + ASerie;
  end;
  if Trim(ANomeComputador) <> '' then
    Url := Url + '&nome_computador=' + TNetEncoding.URL.Encode(ANomeComputador);
  if Trim(ANumeroDocumento) <> '' then
    Url := Url + '&numero_documento=' + TNetEncoding.URL.Encode(Trim(ANumeroDocumento));

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
        Item.NomeComputador := ItemObj.GetValue<string>('nome_computador', '');
        Item.GrupoConferencia := ItemObj.GetValue<string>('grupo_conferencia', '');
        Item.DataVenda := ItemObj.GetValue<string>('data_venda', '');
        Item.HoraVenda := ItemObj.GetValue<string>('hora_venda', '');
        Item.DataTransmissao := ItemObj.GetValue<string>('data_transmissao', '');
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
        if Assigned(ItemObj.GetValue('base_icms')) then
          Item.BaseICMS := JsonToCurrency(ItemObj.GetValue('base_icms').Value);
        if Assigned(ItemObj.GetValue('icms')) then
          Item.ICMS := JsonToCurrency(ItemObj.GetValue('icms').Value);
        if Assigned(ItemObj.GetValue('pis')) then
          Item.PIS := JsonToCurrency(ItemObj.GetValue('pis').Value);
        if Assigned(ItemObj.GetValue('cofins')) then
          Item.COFINS := JsonToCurrency(ItemObj.GetValue('cofins').Value);
        if Assigned(ItemObj.GetValue('imposto_federal')) then
          Item.ImpostoFederal := JsonToCurrency(ItemObj.GetValue('imposto_federal').Value);
        if Assigned(ItemObj.GetValue('imposto_estadual')) then
          Item.ImpostoEstadual := JsonToCurrency(ItemObj.GetValue('imposto_estadual').Value);
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
