unit ConfereArquivo.Types;

interface

uses
  System.SysUtils;

const
  CONFERE_SYNC_REVISION = 5;

type
  TConfereNFCeStatus = (
    nsIgnorada,
    nsAutorizada,
    nsPendenteTransmissao,
    nsRejeitada,
    nsCancelada,
    nsContingencia,
    nsContingenciaAutorizada,
    nsContingenciaPendente
  );

  TConfereEmpresaInfo = record
    IDEmpresaECF: Integer;
    IDEmpresaERP: Integer;
    RazaoSocial: string;
    NomeFantasia: string;
    CNPJ: string;
    InscricaoEstadual: string;
    CRT: string;
    TipoRegime: string;
    Cidade: string;
    UF: string;
    CodigoIBGECidade: Integer;
    NFCeOff: string;
    DesativarTransmissao: string;
    NomeComputador: string;
  end;

  TConfereNFeSaidaRecord = record
    SourceID: Integer;
    IDEmpresa: Integer;
    NumeroNota: Integer;
    SerieNotaFiscal: Integer;
    SerieNota: string;
    CodigoModelo: Integer;
    TipoNota: Integer;
    DataEmissao: TDateTime;
    DataSaida: TDateTime;
    HoraSaida: string;
    ChaveAcesso: string;
    Protocolo: string;
    StatusCancelado: string;
    StatusTransmitida: string;
    StatusRetorno: string;
    CanceladaNF: string;
    ValorTotal: Currency;
    ValorProdutos: Currency;
    Desconto: Currency;
    ValorFrete: Currency;
    ValorSeguro: Currency;
    OutrasDespesas: Currency;
    ValorOutro: Currency;
    BaseICMS: Currency;
    ValorICMS: Currency;
    BaseST: Currency;
    ValorST: Currency;
    ValorIPI: Currency;
    ValorPIS: Currency;
    ValorCOFINS: Currency;
    ValorPISST: Currency;
    ValorCOFINSST: Currency;
    Recibo: string;
    Web: string;
    TipoPagamento: Integer;
    CodigoNumerico: Integer;
    DocumentoCliente: string;
    XMLPresent: Boolean;
    HashIncremento: Integer;
    StatusOperacional: string;
  end;

  TConfereNFeEntradaRecord = record
    SourceID: Integer;
    IDEmpresa: Integer;
    EmpresaCNPJ: string;
    EmpresaRazaoSocial: string;
    EmpresaNomeFantasia: string;
    EmpresaInscricaoEstadual: string;
    EmpresaCRT: string;
    DataEmissao: TDateTime;
    DataEntrada: TDateTime;
    TipoEntrada: string;
    NumeroNota: string;
    SerieNota: string;
    CodigoModelo: Integer;
    TotalEntrada: Currency;
    Acrescimo: Currency;
    Desconto: Currency;
    Frete: Currency;
    ICMSFrete: Currency;
    BaseSubTrib: Currency;
    ValorICMSSub: Currency;
    TotalProdutos: Currency;
    ValorAbatimento: Currency;
    ValorSeguro: Currency;
    ValorOutrasDespesas: Currency;
    BaseICMS: Currency;
    ValorICMS: Currency;
    ValorIPI: Currency;
    ValorPIS: Currency;
    ValorCOFINS: Currency;
    ValorPISST: Currency;
    ValorCOFINSST: Currency;
    ValorST: Currency;
    ChaveAcesso: string;
    NomeXML: string;
    Web: string;
    UF: string;
    IE: string;
    DocumentoFornecedor: string;
    CodFornecedor: Integer;
    HashIncremento: Integer;
    StatusOperacional: string;
  end;

  TConfereNFCeRecord = record
    SourceID: Integer;
    IDECFMovimento: Integer;
    IDEmpresaECF: Integer;
    DataVenda: TDateTime;
    HoraVenda: string;
    StatusVenda: string;
    NumeroNFCe: Integer;
    SerieNFCe: Integer;
    ChaveAcesso: string;
    Protocolo: string;
    NFCeCancelada: string;
    NFCeOffline: string;
    CodigoNumerico: Integer;
    CaminhoXML: string;
    SatXML: string;
    EmitiuSAT: string;
    NumSAT: Integer;
    StatusErro: string;
    DHCont: string;
    DataAutorizacao: TDateTime;
    ValorVenda: Currency;
    ValorFinal: Currency;
    TotalProdutos: Currency;
    TotalDocumento: Currency;
    BaseICMS: Currency;
    ICMS: Currency;
    PIS: Currency;
    COFINS: Currency;
    Imposto: Currency;
    ImpostoEstadual: Currency;
    DocumentoCliente: string;
    NomeCliente: string;
    HashIncremento: Integer;
    StatusOperacional: TConfereNFCeStatus;
  end;

  TConfereQueueItem = record
    QueueID: Integer;
    SourceID: Integer;
    PayloadJson: string;
    Attempts: Integer;
    HashIncremento: Integer;
  end;

function ConfereStatusToString(const AStatus: TConfereNFCeStatus): string;
function ConfereStatusFromRecord(const ARecord: TConfereNFCeRecord): TConfereNFCeStatus;
function ConfereNFeSaidaStatusFromRecord(const ARecord: TConfereNFeSaidaRecord): string;
function ConfereNFeEntradaStatusFromRecord(const ARecord: TConfereNFeEntradaRecord): string;
function NormalizeDigits(const AValue: string): string;

implementation

function NormalizeDigits(const AValue: string): string;
var
  Ch: Char;
begin
  Result := '';
  for Ch in AValue do
    if CharInSet(Ch, ['0'..'9']) then
      Result := Result + Ch;
end;

function ConfereStatusToString(const AStatus: TConfereNFCeStatus): string;
begin
  case AStatus of
    nsAutorizada:
      Result := 'AUTORIZADA';
    nsPendenteTransmissao:
      Result := 'PENDENTE_TRANSMISSAO';
    nsRejeitada:
      Result := 'REJEITADA';
    nsCancelada:
      Result := 'CANCELADA';
    nsContingencia:
      Result := 'CONTINGENCIA';
    nsContingenciaAutorizada:
      Result := 'CONTINGENCIA_AUTORIZADA';
    nsContingenciaPendente:
      Result := 'CONTINGENCIA_PENDENTE';
  else
    Result := 'IGNORADA';
  end;
end;

function ConfereStatusFromRecord(const ARecord: TConfereNFCeRecord): TConfereNFCeStatus;
var
  HasProtocol: Boolean;
  HasKey: Boolean;
  HasError: Boolean;
  IsCanceled: Boolean;
  IsOffline: Boolean;
  HasNumero: Boolean;
begin
  HasProtocol := (Trim(ARecord.Protocolo) <> '') or (ARecord.DataAutorizacao > 0);
  HasKey := Trim(ARecord.ChaveAcesso) <> '';
  HasError := Trim(ARecord.StatusErro) <> '';
  IsCanceled := not SameText(Trim(ARecord.NFCeCancelada), 'N') and
                (Trim(ARecord.NFCeCancelada) <> '');
  IsOffline := SameText(Trim(ARecord.NFCeOffline), 'S') or
               (Trim(ARecord.DHCont) <> '');
  HasNumero := ARecord.NumeroNFCe > 0;

  if not (HasNumero or HasKey) then
    Exit(nsIgnorada);

  if IsCanceled then
    Exit(nsCancelada);

  if HasProtocol then
    Exit(nsAutorizada);

  if HasError then
    Exit(nsRejeitada);

  if IsOffline and not HasProtocol then
    Exit(nsContingenciaPendente);

  if HasNumero then
    Exit(nsPendenteTransmissao);

  Result := nsIgnorada;
end;

function ConfereNFeSaidaStatusFromRecord(const ARecord: TConfereNFeSaidaRecord): string;
begin
  if SameText(Trim(ARecord.StatusCancelado), 'S') then
    Exit('CANCELADA');

  if Trim(ARecord.Protocolo) <> '' then
    Exit('AUTORIZADA');

  Result := 'NAO_AUTORIZADA';
end;

function ConfereNFeEntradaStatusFromRecord(const ARecord: TConfereNFeEntradaRecord): string;
begin
  if (Trim(ARecord.ChaveAcesso) <> '') or (Trim(ARecord.NomeXML) <> '') then
    Exit('AUTORIZADA');

  Result := 'NAO_AUTORIZADA';
end;

end.
