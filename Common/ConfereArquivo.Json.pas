unit ConfereArquivo.Json;

interface

uses
  System.JSON, System.SysUtils, System.DateUtils,
  ConfereArquivo.Types;

function BuildNFCeJson(const AEmpresa: TConfereEmpresaInfo;
  const ARecord: TConfereNFCeRecord): TJSONObject;
function BuildNFeSaidaJson(const AEmpresa: TConfereEmpresaInfo;
  const ARecord: TConfereNFeSaidaRecord): TJSONObject;
function BuildNFeEntradaJson(const AEmpresa: TConfereEmpresaInfo;
  const ARecord: TConfereNFeEntradaRecord): TJSONObject;
function BuildLoteJson(const ACNPJ, AInstalacaoID: string;
  const AItems: TArray<TConfereQueueItem>): TJSONObject;

implementation

function JsonDateOrNull(const AValue: TDateTime): TJSONValue;
begin
  if AValue <= 0 then
    Exit(TJSONNull.Create);

  Result := TJSONString.Create(FormatDateTime('yyyy"-"mm"-"dd', AValue));
end;

function JsonNumberOrZero(const AValue: Currency): TJSONNumber;
begin
  Result := TJSONNumber.Create(StringReplace(FormatFloat('0.######', AValue), ',', '.', [rfReplaceAll]));
end;

function BuildNFCeJson(const AEmpresa: TConfereEmpresaInfo;
  const ARecord: TConfereNFCeRecord): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('payload_version', TJSONNumber.Create(1));
  Result.AddPair('empresa', TJSONObject.Create
    .AddPair('id_ecf_empresa', TJSONNumber.Create(AEmpresa.IDEmpresaECF))
    .AddPair('id_empresa_erp', TJSONNumber.Create(AEmpresa.IDEmpresaERP))
    .AddPair('cnpj', NormalizeDigits(AEmpresa.CNPJ))
    .AddPair('razao_social', AEmpresa.RazaoSocial)
    .AddPair('nome_fantasia', AEmpresa.NomeFantasia)
    .AddPair('inscricao_estadual', NormalizeDigits(AEmpresa.InscricaoEstadual))
    .AddPair('crt', AEmpresa.CRT)
    .AddPair('tipo_regime', AEmpresa.TipoRegime)
    .AddPair('cidade', AEmpresa.Cidade)
    .AddPair('uf', AEmpresa.UF)
    .AddPair('codigo_ibge_cidade', TJSONNumber.Create(AEmpresa.CodigoIBGECidade))
    .AddPair('nome_computador', AEmpresa.NomeComputador));

  Result.AddPair('venda', TJSONObject.Create
    .AddPair('source_id', TJSONNumber.Create(ARecord.SourceID))
    .AddPair('id_ecf_movimento', TJSONNumber.Create(ARecord.IDECFMovimento))
    .AddPair('data_venda', JsonDateOrNull(ARecord.DataVenda))
    .AddPair('hora_venda', ARecord.HoraVenda)
    .AddPair('status_venda', ARecord.StatusVenda)
    .AddPair('num_nfce', TJSONNumber.Create(ARecord.NumeroNFCe))
    .AddPair('serie_nfce', TJSONNumber.Create(ARecord.SerieNFCe))
    .AddPair('chave_acesso', ARecord.ChaveAcesso)
    .AddPair('protocolo', ARecord.Protocolo)
    .AddPair('nfce_cancelada', ARecord.NFCeCancelada)
    .AddPair('nfce_offline', ARecord.NFCeOffline)
    .AddPair('codigo_numerico_nfce', TJSONNumber.Create(ARecord.CodigoNumerico))
    .AddPair('caminho_xml', ARecord.CaminhoXML)
    .AddPair('sat_xml', ARecord.SatXML)
    .AddPair('emitiu_sat', ARecord.EmitiuSAT)
    .AddPair('num_sat', TJSONNumber.Create(ARecord.NumSAT))
    .AddPair('status_erro', ARecord.StatusErro)
    .AddPair('dhcont', ARecord.DHCont)
    .AddPair('data_autorizacao', JsonDateOrNull(ARecord.DataAutorizacao))
    .AddPair('valor_venda', JsonNumberOrZero(ARecord.ValorVenda))
    .AddPair('valor_final', JsonNumberOrZero(ARecord.ValorFinal))
    .AddPair('total_produtos', JsonNumberOrZero(ARecord.TotalProdutos))
    .AddPair('total_documento', JsonNumberOrZero(ARecord.TotalDocumento))
    .AddPair('base_icms', JsonNumberOrZero(ARecord.BaseICMS))
    .AddPair('icms', JsonNumberOrZero(ARecord.ICMS))
    .AddPair('pis', JsonNumberOrZero(ARecord.PIS))
    .AddPair('cofins', JsonNumberOrZero(ARecord.COFINS))
    .AddPair('imposto', JsonNumberOrZero(ARecord.Imposto))
    .AddPair('imposto_estadual', JsonNumberOrZero(ARecord.ImpostoEstadual))
    .AddPair('documento_cliente', NormalizeDigits(ARecord.DocumentoCliente))
    .AddPair('nome_cliente', ARecord.NomeCliente)
    .AddPair('nome_computador', AEmpresa.NomeComputador)
    .AddPair('hash_incremento', TJSONNumber.Create(ARecord.HashIncremento))
    .AddPair('status_operacional', ConfereStatusToString(ARecord.StatusOperacional)));
end;

function BuildNFeSaidaJson(const AEmpresa: TConfereEmpresaInfo;
  const ARecord: TConfereNFeSaidaRecord): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('payload_version', TJSONNumber.Create(1));
  Result.AddPair('empresa', TJSONObject.Create
    .AddPair('id_empresa_erp', TJSONNumber.Create(ARecord.IDEmpresa))
    .AddPair('cnpj', NormalizeDigits(AEmpresa.CNPJ))
    .AddPair('razao_social', AEmpresa.RazaoSocial)
    .AddPair('nome_fantasia', AEmpresa.NomeFantasia)
    .AddPair('inscricao_estadual', NormalizeDigits(AEmpresa.InscricaoEstadual))
    .AddPair('crt', AEmpresa.CRT)
    .AddPair('tipo_regime', AEmpresa.TipoRegime)
    .AddPair('cidade', AEmpresa.Cidade)
    .AddPair('uf', AEmpresa.UF)
    .AddPair('nome_computador', AEmpresa.NomeComputador));

  Result.AddPair('nota', TJSONObject.Create
    .AddPair('source_id', TJSONNumber.Create(ARecord.SourceID))
    .AddPair('id_empresa', TJSONNumber.Create(ARecord.IDEmpresa))
    .AddPair('numero_nota', TJSONNumber.Create(ARecord.NumeroNota))
    .AddPair('serie_nota_fiscal', TJSONNumber.Create(ARecord.SerieNotaFiscal))
    .AddPair('serie_nota', ARecord.SerieNota)
    .AddPair('codigo_modelo', TJSONNumber.Create(ARecord.CodigoModelo))
    .AddPair('tipo_nota', TJSONNumber.Create(ARecord.TipoNota))
    .AddPair('data_emissao', JsonDateOrNull(ARecord.DataEmissao))
    .AddPair('data_saida', JsonDateOrNull(ARecord.DataSaida))
    .AddPair('hora_saida', ARecord.HoraSaida)
    .AddPair('chave_acesso', ARecord.ChaveAcesso)
    .AddPair('protocolo', ARecord.Protocolo)
    .AddPair('status_cancelado', ARecord.StatusCancelado)
    .AddPair('status_transmitida', ARecord.StatusTransmitida)
    .AddPair('status_retorno', ARecord.StatusRetorno)
    .AddPair('cancelada_nf', ARecord.CanceladaNF)
    .AddPair('valor_total', JsonNumberOrZero(ARecord.ValorTotal))
    .AddPair('valor_produtos', JsonNumberOrZero(ARecord.ValorProdutos))
    .AddPair('desconto', JsonNumberOrZero(ARecord.Desconto))
    .AddPair('valor_frete', JsonNumberOrZero(ARecord.ValorFrete))
    .AddPair('valor_seguro', JsonNumberOrZero(ARecord.ValorSeguro))
    .AddPair('outras_despesas', JsonNumberOrZero(ARecord.OutrasDespesas))
    .AddPair('valor_outro', JsonNumberOrZero(ARecord.ValorOutro))
    .AddPair('base_icms', JsonNumberOrZero(ARecord.BaseICMS))
    .AddPair('valor_icms', JsonNumberOrZero(ARecord.ValorICMS))
    .AddPair('base_st', JsonNumberOrZero(ARecord.BaseST))
    .AddPair('valor_st', JsonNumberOrZero(ARecord.ValorST))
    .AddPair('valor_ipi', JsonNumberOrZero(ARecord.ValorIPI))
    .AddPair('valor_pis', JsonNumberOrZero(ARecord.ValorPIS))
    .AddPair('valor_cofins', JsonNumberOrZero(ARecord.ValorCOFINS))
    .AddPair('valor_pis_st', JsonNumberOrZero(ARecord.ValorPISST))
    .AddPair('valor_cofins_st', JsonNumberOrZero(ARecord.ValorCOFINSST))
    .AddPair('recibo', ARecord.Recibo)
    .AddPair('web', ARecord.Web)
    .AddPair('tipo_pagamento', TJSONNumber.Create(ARecord.TipoPagamento))
    .AddPair('codigo_numerico', TJSONNumber.Create(ARecord.CodigoNumerico))
    .AddPair('documento_cliente', NormalizeDigits(ARecord.DocumentoCliente))
    .AddPair('xml_presente', TJSONBool.Create(ARecord.XMLPresent))
    .AddPair('nome_computador', AEmpresa.NomeComputador)
    .AddPair('hash_incremento', TJSONNumber.Create(ARecord.HashIncremento))
    .AddPair('status_operacional', ARecord.StatusOperacional));
end;

function BuildNFeEntradaJson(const AEmpresa: TConfereEmpresaInfo;
  const ARecord: TConfereNFeEntradaRecord): TJSONObject;
var
  EmpresaCNPJ: string;
  EmpresaRazaoSocial: string;
  EmpresaNomeFantasia: string;
  EmpresaInscricaoEstadual: string;
  EmpresaCRT: string;
begin
  EmpresaCNPJ := ARecord.EmpresaCNPJ;
  if EmpresaCNPJ = '' then
    EmpresaCNPJ := AEmpresa.CNPJ;

  EmpresaRazaoSocial := ARecord.EmpresaRazaoSocial;
  if EmpresaRazaoSocial = '' then
    EmpresaRazaoSocial := AEmpresa.RazaoSocial;

  EmpresaNomeFantasia := ARecord.EmpresaNomeFantasia;
  if EmpresaNomeFantasia = '' then
    EmpresaNomeFantasia := AEmpresa.NomeFantasia;

  EmpresaInscricaoEstadual := ARecord.EmpresaInscricaoEstadual;
  if EmpresaInscricaoEstadual = '' then
    EmpresaInscricaoEstadual := AEmpresa.InscricaoEstadual;

  EmpresaCRT := ARecord.EmpresaCRT;
  if EmpresaCRT = '' then
    EmpresaCRT := AEmpresa.CRT;

  Result := TJSONObject.Create;
  Result.AddPair('payload_version', TJSONNumber.Create(1));
  Result.AddPair('empresa', TJSONObject.Create
    .AddPair('id_empresa_erp', TJSONNumber.Create(ARecord.IDEmpresa))
    .AddPair('cnpj', NormalizeDigits(EmpresaCNPJ))
    .AddPair('razao_social', EmpresaRazaoSocial)
    .AddPair('nome_fantasia', EmpresaNomeFantasia)
    .AddPair('inscricao_estadual', NormalizeDigits(EmpresaInscricaoEstadual))
    .AddPair('crt', EmpresaCRT)
    .AddPair('tipo_regime', AEmpresa.TipoRegime)
    .AddPair('cidade', AEmpresa.Cidade)
    .AddPair('uf', AEmpresa.UF)
    .AddPair('nome_computador', AEmpresa.NomeComputador));

  Result.AddPair('entrada', TJSONObject.Create
    .AddPair('source_id', TJSONNumber.Create(ARecord.SourceID))
    .AddPair('id_empresa', TJSONNumber.Create(ARecord.IDEmpresa))
    .AddPair('data_emissao', JsonDateOrNull(ARecord.DataEmissao))
    .AddPair('data_entrada', JsonDateOrNull(ARecord.DataEntrada))
    .AddPair('tipo_entrada', ARecord.TipoEntrada)
    .AddPair('numero_nota', ARecord.NumeroNota)
    .AddPair('serie_nota', ARecord.SerieNota)
    .AddPair('codigo_modelo', TJSONNumber.Create(ARecord.CodigoModelo))
    .AddPair('total_entrada', JsonNumberOrZero(ARecord.TotalEntrada))
    .AddPair('acrescimo', JsonNumberOrZero(ARecord.Acrescimo))
    .AddPair('desconto', JsonNumberOrZero(ARecord.Desconto))
    .AddPair('frete', JsonNumberOrZero(ARecord.Frete))
    .AddPair('icms_frete', JsonNumberOrZero(ARecord.ICMSFrete))
    .AddPair('base_sub_trib', JsonNumberOrZero(ARecord.BaseSubTrib))
    .AddPair('valor_icms_sub', JsonNumberOrZero(ARecord.ValorICMSSub))
    .AddPair('total_produtos', JsonNumberOrZero(ARecord.TotalProdutos))
    .AddPair('valor_abatimento', JsonNumberOrZero(ARecord.ValorAbatimento))
    .AddPair('valor_seguro', JsonNumberOrZero(ARecord.ValorSeguro))
    .AddPair('valor_outras_despesas', JsonNumberOrZero(ARecord.ValorOutrasDespesas))
    .AddPair('base_icms', JsonNumberOrZero(ARecord.BaseICMS))
    .AddPair('valor_icms', JsonNumberOrZero(ARecord.ValorICMS))
    .AddPair('valor_ipi', JsonNumberOrZero(ARecord.ValorIPI))
    .AddPair('valor_pis', JsonNumberOrZero(ARecord.ValorPIS))
    .AddPair('valor_cofins', JsonNumberOrZero(ARecord.ValorCOFINS))
    .AddPair('valor_pis_st', JsonNumberOrZero(ARecord.ValorPISST))
    .AddPair('valor_cofins_st', JsonNumberOrZero(ARecord.ValorCOFINSST))
    .AddPair('valor_st', JsonNumberOrZero(ARecord.ValorST))
    .AddPair('chave_acesso', ARecord.ChaveAcesso)
    .AddPair('nome_xml', ARecord.NomeXML)
    .AddPair('web', ARecord.Web)
    .AddPair('uf_fornecedor', ARecord.UF)
    .AddPair('ie_fornecedor', ARecord.IE)
    .AddPair('documento_fornecedor', NormalizeDigits(ARecord.DocumentoFornecedor))
    .AddPair('cod_fornecedor', TJSONNumber.Create(ARecord.CodFornecedor))
    .AddPair('nome_computador', AEmpresa.NomeComputador)
    .AddPair('hash_incremento', TJSONNumber.Create(ARecord.HashIncremento))
    .AddPair('status_operacional', ARecord.StatusOperacional));
end;

function BuildLoteJson(const ACNPJ, AInstalacaoID: string;
  const AItems: TArray<TConfereQueueItem>): TJSONObject;
var
  Arr: TJSONArray;
  Item: TConfereQueueItem;
  Parsed: TJSONValue;
begin
  Arr := TJSONArray.Create;
  for Item in AItems do
  begin
    Parsed := TJSONObject.ParseJSONValue(Item.PayloadJson);
    if Assigned(Parsed) then
      Arr.AddElement(Parsed)
    else
      Arr.AddElement(TJSONObject.Create.AddPair('source_id', TJSONNumber.Create(Item.SourceID)));
  end;

  Result := TJSONObject.Create;
  Result.AddPair('cnpj_empresa', NormalizeDigits(ACNPJ));
  Result.AddPair('instalacao_id', AInstalacaoID);
  Result.AddPair('nome_computador', GetEnvironmentVariable('COMPUTERNAME'));
  Result.AddPair('gerado_em', DateToISO8601(Now, False));
  Result.AddPair('quantidade', TJSONNumber.Create(Length(AItems)));
  Result.AddPair('notas', Arr);
end;

end.
