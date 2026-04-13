unit ConfereArquivo.Agent.SourceNFeSaida;

interface

uses
  System.SysUtils, System.Generics.Collections, FireDAC.Comp.Client,
  ConfereArquivo.Agent.Config, ConfereArquivo.Types;

type
  TConfereAgentSourceNFeSaida = class
  private
    FConfig: TConfereAgentConfig;
    FConnection: TFDConnection;
    procedure EnsureConnected;
    procedure EnsureSyncSchema;
    function SyncColumnExists(const AColumn: string): Boolean;
  public
    constructor Create(const AConfig: TConfereAgentConfig);
    destructor Destroy; override;
    function Validate(out AMessage: string): Boolean;
    function LoadEmpresa(out AEmpresa: TConfereEmpresaInfo): Boolean;
    function LoadChangedNotas(const ALastID, AWindowDays: Integer): TArray<TConfereNFeSaidaRecord>;
    function IsSynced(const AItem: TConfereNFeSaidaRecord): Boolean;
    procedure MarkAsSynced(const ASourceID, AHashIncremento: Integer; const AStatusOperacional: string);
  end;

implementation

uses
  System.DateUtils, System.Hash, Data.DB, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  ConfereArquivo.Logger;

function CurrencyFieldValue(const AField: TField): Currency;
begin
  if Assigned(AField) and (not AField.IsNull) then
    Result := AField.AsCurrency
  else
    Result := 0;
end;

function DateFieldValue(const AField: TField): TDateTime;
begin
  if Assigned(AField) and (not AField.IsNull) then
    Result := AField.AsDateTime
  else
    Result := 0;
end;

function IntFieldValue(const AField: TField): Integer;
begin
  if Assigned(AField) and (not AField.IsNull) then
    Result := AField.AsInteger
  else
    Result := 0;
end;

function TimeFieldToString(const AField: TField): string;
begin
  if Assigned(AField) and (not AField.IsNull) then
    Result := FormatDateTime('hh:nn:ss', AField.AsDateTime)
  else
    Result := '';
end;

function CalcHashIncremento(const ABase: string): Integer;
var
  HashHex: string;
begin
  HashHex := Copy(THashMD5.GetHashString(ABase), 1, 8);
  Result := Integer(StrToInt64Def('$' + HashHex, 0) and $7FFFFFFF);
end;

constructor TConfereAgentSourceNFeSaida.Create(const AConfig: TConfereAgentConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FConnection := TFDConnection.Create(nil);
  FConnection.LoginPrompt := False;
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'IB';
  FConnection.Params.Database := FConfig.NFeSaidaDatabasePath;
  FConnection.Params.UserName := FConfig.FirebirdUser;
  FConnection.Params.Password := FConfig.FirebirdPassword;
  FConnection.Params.Values['CharacterSet'] := 'WIN1252';
end;

destructor TConfereAgentSourceNFeSaida.Destroy;
begin
  FreeAndNil(FConnection);
  inherited Destroy;
end;

procedure TConfereAgentSourceNFeSaida.EnsureConnected;
begin
  if not FConnection.Connected then
    FConnection.Connected := True;
end;

function TConfereAgentSourceNFeSaida.SyncColumnExists(const AColumn: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select count(*) qtd from rdb$relation_fields where rdb$relation_name = ''CONFERE_ARQUIVO_SYNC_NFE_SAIDA'' and rdb$field_name = :f';
    Q.ParamByName('f').AsString := UpperCase(AColumn);
    Q.Open;
    Result := Q.FieldByName('QTD').AsInteger > 0;
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentSourceNFeSaida.EnsureSyncSchema;
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select count(*) qtd from rdb$relations where rdb$relation_name = ''CONFERE_ARQUIVO_SYNC_NFE_SAIDA''';
    Q.Open;
    if Q.FieldByName('QTD').AsInteger = 0 then
    begin
      Q.Close;
      Q.SQL.Text :=
        'create table CONFERE_ARQUIVO_SYNC_NFE_SAIDA (' +
        '  SOURCE_ID integer not null,' +
        '  HASH_INCREMENTO integer not null,' +
        '  PAYLOAD_REV integer default 0,' +
        '  STATUS_OPERACIONAL varchar(40),' +
        '  ULTIMO_ENVIO timestamp,' +
        '  constraint PK_CONFERE_ARQ_SYNC_NFE primary key (SOURCE_ID)' +
        ')';
      Q.ExecSQL;
      FConnection.Commit;
    end;

    if not SyncColumnExists('PAYLOAD_REV') then
    begin
      Q.Close;
      Q.SQL.Text := 'alter table CONFERE_ARQUIVO_SYNC_NFE_SAIDA add PAYLOAD_REV integer default 0';
      Q.ExecSQL;
      FConnection.Commit;
    end;
  finally
    Q.Free;
  end;
end;

function TConfereAgentSourceNFeSaida.Validate(out AMessage: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  AMessage := '';
  Q := TFDQuery.Create(nil);
  try
    EnsureConnected;
    EnsureSyncSchema;
    Q.Connection := FConnection;
    Q.SQL.Text := 'select first 1 cod_nf from nota_fiscal';
    Q.Open;
    AMessage := 'Banco NFe Saida validado com sucesso.';
    Result := True;
  except
    on E: Exception do
    begin
      AMessage := E.Message;
      ConfereLogError('Falha validando fonte NFe Saida: ' + E.Message);
    end;
  end;
  Q.Free;
end;

function TConfereAgentSourceNFeSaida.LoadEmpresa(out AEmpresa: TConfereEmpresaInfo): Boolean;
var
  Q: TFDQuery;
begin
  FillChar(AEmpresa, SizeOf(AEmpresa), 0);
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    EnsureConnected;
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select first 1 e.cod_emp, e.razao_emp, e.fantasia_emp, e.cnpj_emp, e.insc_emp, e.regime ' +
      'from empresa e ' +
      'join nota_fiscal n on n.cod_emp = e.cod_emp and n.ent_sai_nf = ''S'' ' +
      'order by e.cod_emp';
    Q.Open;
    if not Q.IsEmpty then
    begin
      AEmpresa.IDEmpresaERP := Q.FieldByName('COD_EMP').AsInteger;
      AEmpresa.RazaoSocial := Q.FieldByName('RAZAO_EMP').AsString;
      AEmpresa.NomeFantasia := Q.FieldByName('FANTASIA_EMP').AsString;
      AEmpresa.CNPJ := Q.FieldByName('CNPJ_EMP').AsString;
      AEmpresa.InscricaoEstadual := Q.FieldByName('INSC_EMP').AsString;
      AEmpresa.CRT := Q.FieldByName('REGIME').AsString;
      AEmpresa.NomeComputador := Trim(GetEnvironmentVariable('COMPUTERNAME'));
      Result := True;
    end;
  finally
    Q.Free;
  end;
end;

function TConfereAgentSourceNFeSaida.IsSynced(const AItem: TConfereNFeSaidaRecord): Boolean;
var
  Q: TFDQuery;
begin
  EnsureSyncSchema;
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select hash_incremento, coalesce(payload_rev, 0) payload_rev from CONFERE_ARQUIVO_SYNC_NFE_SAIDA where source_id = :id';
    Q.ParamByName('id').AsInteger := AItem.SourceID;
    Q.Open;
    if not Q.IsEmpty then
      Result := (Q.FieldByName('HASH_INCREMENTO').AsInteger = AItem.HashIncremento) and
                (Q.FieldByName('PAYLOAD_REV').AsInteger = CONFERE_SYNC_REVISION);
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentSourceNFeSaida.MarkAsSynced(const ASourceID,
  AHashIncremento: Integer; const AStatusOperacional: string);
var
  Q: TFDQuery;
begin
  EnsureSyncSchema;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'update or insert into CONFERE_ARQUIVO_SYNC_NFE_SAIDA (source_id, hash_incremento, payload_rev, status_operacional, ultimo_envio) ' +
      'values (:source_id, :hash_incremento, :payload_rev, :status_operacional, :ultimo_envio) matching (source_id)';
    Q.ParamByName('source_id').AsInteger := ASourceID;
    Q.ParamByName('hash_incremento').AsInteger := AHashIncremento;
    Q.ParamByName('payload_rev').AsInteger := CONFERE_SYNC_REVISION;
    Q.ParamByName('status_operacional').AsString := AStatusOperacional;
    Q.ParamByName('ultimo_envio').AsDateTime := Now;
    Q.ExecSQL;
    FConnection.Commit;
  finally
    Q.Free;
  end;
end;

function TConfereAgentSourceNFeSaida.LoadChangedNotas(const ALastID,
  AWindowDays: Integer): TArray<TConfereNFeSaidaRecord>;
var
  Q: TFDQuery;
  L: TList<TConfereNFeSaidaRecord>;
  Item: TConfereNFeSaidaRecord;
  HashBase: string;
begin
  Q := TFDQuery.Create(nil);
  L := TList<TConfereNFeSaidaRecord>.Create;
  try
    EnsureConnected;
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select n.cod_nf, n.cod_emp, n.numero_nota_nf, n.serie_nota_fiscal, n.serie_nota, n.cod_modelo, n.tipo_nota, ' +
      'n.data_emissao_nf, n.data_saida_nf, n.hora_saida_nf, n.chave_acesso_nfe, n.protocolo_nfe, ' +
      'n.status_cancelado, n.status_transmitida, n.status_retorno, n.cancelada_nf, ' +
      'n.valor_total_nf, n.valor_total_prod_nf, n.desconto_nf, n.valor_frete_nf, n.valor_seguro_nf, ' +
      'n.outras_despesas_nf, n.voutro, n.base_calculo_icms_nf, n.valor_icms_nf, n.base_subst_nf, n.valor_subst_nf, ' +
      'n.valor_ipi_nf, n.vl_pis, n.vl_cofins, n.vl_pis_st, n.vl_cofins_st, n.recibo, n.web, n.tpag, n.codigo_numerico, n.cnpj, n.xml_nfe ' +
      'from nota_fiscal n ' +
      'where n.ent_sai_nf = ''S'' and ((n.cod_nf > :last_id) or (n.data_emissao_nf >= :window_date)) ' +
      'order by n.cod_nf';
    Q.ParamByName('last_id').AsInteger := ALastID;
    Q.ParamByName('window_date').AsDate := IncDay(Date, -AWindowDays);
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(Item, SizeOf(Item), 0);
      Item.SourceID := IntFieldValue(Q.FieldByName('COD_NF'));
      Item.IDEmpresa := IntFieldValue(Q.FieldByName('COD_EMP'));
      Item.NumeroNota := IntFieldValue(Q.FieldByName('NUMERO_NOTA_NF'));
      Item.SerieNotaFiscal := IntFieldValue(Q.FieldByName('SERIE_NOTA_FISCAL'));
      Item.SerieNota := Trim(Q.FieldByName('SERIE_NOTA').AsString);
      Item.CodigoModelo := IntFieldValue(Q.FieldByName('COD_MODELO'));
      Item.TipoNota := IntFieldValue(Q.FieldByName('TIPO_NOTA'));
      Item.DataEmissao := DateFieldValue(Q.FieldByName('DATA_EMISSAO_NF'));
      Item.DataSaida := DateFieldValue(Q.FieldByName('DATA_SAIDA_NF'));
      Item.HoraSaida := TimeFieldToString(Q.FieldByName('HORA_SAIDA_NF'));
      Item.ChaveAcesso := Trim(Q.FieldByName('CHAVE_ACESSO_NFE').AsString);
      Item.Protocolo := Trim(Q.FieldByName('PROTOCOLO_NFE').AsString);
      Item.StatusCancelado := Trim(Q.FieldByName('STATUS_CANCELADO').AsString);
      Item.StatusTransmitida := Trim(Q.FieldByName('STATUS_TRANSMITIDA').AsString);
      Item.StatusRetorno := Trim(Q.FieldByName('STATUS_RETORNO').AsString);
      Item.CanceladaNF := Trim(Q.FieldByName('CANCELADA_NF').AsString);
      Item.ValorTotal := CurrencyFieldValue(Q.FieldByName('VALOR_TOTAL_NF'));
      Item.ValorProdutos := CurrencyFieldValue(Q.FieldByName('VALOR_TOTAL_PROD_NF'));
      Item.Desconto := CurrencyFieldValue(Q.FieldByName('DESCONTO_NF'));
      Item.ValorFrete := CurrencyFieldValue(Q.FieldByName('VALOR_FRETE_NF'));
      Item.ValorSeguro := CurrencyFieldValue(Q.FieldByName('VALOR_SEGURO_NF'));
      Item.OutrasDespesas := CurrencyFieldValue(Q.FieldByName('OUTRAS_DESPESAS_NF'));
      Item.ValorOutro := CurrencyFieldValue(Q.FieldByName('VOUTRO'));
      Item.BaseICMS := CurrencyFieldValue(Q.FieldByName('BASE_CALCULO_ICMS_NF'));
      Item.ValorICMS := CurrencyFieldValue(Q.FieldByName('VALOR_ICMS_NF'));
      Item.BaseST := CurrencyFieldValue(Q.FieldByName('BASE_SUBST_NF'));
      Item.ValorST := CurrencyFieldValue(Q.FieldByName('VALOR_SUBST_NF'));
      Item.ValorIPI := CurrencyFieldValue(Q.FieldByName('VALOR_IPI_NF'));
      Item.ValorPIS := CurrencyFieldValue(Q.FieldByName('VL_PIS'));
      Item.ValorCOFINS := CurrencyFieldValue(Q.FieldByName('VL_COFINS'));
      Item.ValorPISST := CurrencyFieldValue(Q.FieldByName('VL_PIS_ST'));
      Item.ValorCOFINSST := CurrencyFieldValue(Q.FieldByName('VL_COFINS_ST'));
      Item.Recibo := Trim(Q.FieldByName('RECIBO').AsString);
      Item.Web := Trim(Q.FieldByName('WEB').AsString);
      Item.TipoPagamento := IntFieldValue(Q.FieldByName('TPAG'));
      Item.CodigoNumerico := IntFieldValue(Q.FieldByName('CODIGO_NUMERICO'));
      Item.DocumentoCliente := Trim(Q.FieldByName('CNPJ').AsString);
      Item.XMLPresent := not Q.FieldByName('XML_NFE').IsNull;

      Item.StatusOperacional := ConfereNFeSaidaStatusFromRecord(Item);
      HashBase := Format('%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s',
        [Item.SourceID, Item.ChaveAcesso, Item.Protocolo, Item.StatusCancelado, Item.StatusTransmitida,
         Item.StatusRetorno, FormatFloat('0.00', Item.ValorTotal), FormatFloat('0.00', Item.BaseICMS),
         FormatFloat('0.00', Item.ValorICMS), FormatDateTime('yyyy-mm-dd', Item.DataEmissao), Item.Recibo]);
      Item.HashIncremento := CalcHashIncremento(HashBase);
      L.Add(Item);
      Q.Next;
    end;
    Result := L.ToArray;
  finally
    L.Free;
    Q.Free;
  end;
end;

end.
