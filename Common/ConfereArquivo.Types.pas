unit ConfereArquivo.Types;

interface

uses
  System.SysUtils;

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

end.
