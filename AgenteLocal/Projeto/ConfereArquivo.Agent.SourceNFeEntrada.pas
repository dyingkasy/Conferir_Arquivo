unit ConfereArquivo.Agent.SourceNFeEntrada;

interface

uses
  System.SysUtils, System.Generics.Collections, FireDAC.Comp.Client,
  ConfereArquivo.Agent.Config, ConfereArquivo.Types;

type
  TConfereAgentSourceNFeEntrada = class
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
    function LoadChangedEntradas(const ALastID, AWindowDays: Integer): TArray<TConfereNFeEntradaRecord>;
    function IsSynced(const AItem: TConfereNFeEntradaRecord): Boolean;
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

function CalcHashIncremento(const ABase: string): Integer;
var
  HashHex: string;
begin
  HashHex := Copy(THashMD5.GetHashString(ABase), 1, 8);
  Result := Integer(StrToInt64Def('$' + HashHex, 0) and $7FFFFFFF);
end;

constructor TConfereAgentSourceNFeEntrada.Create(const AConfig: TConfereAgentConfig);
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

destructor TConfereAgentSourceNFeEntrada.Destroy;
begin
  FreeAndNil(FConnection);
  inherited Destroy;
end;

procedure TConfereAgentSourceNFeEntrada.EnsureConnected;
begin
  if not FConnection.Connected then
    FConnection.Connected := True;
end;

function TConfereAgentSourceNFeEntrada.SyncColumnExists(const AColumn: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select count(*) qtd from rdb$relation_fields where rdb$relation_name = ''CONFERE_ARQUIVO_SYNC_NFE_ENTRADA'' and rdb$field_name = :f';
    Q.ParamByName('f').AsString := UpperCase(AColumn);
    Q.Open;
    Result := Q.FieldByName('QTD').AsInteger > 0;
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentSourceNFeEntrada.EnsureSyncSchema;
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select count(*) qtd from rdb$relations where rdb$relation_name = ''CONFERE_ARQUIVO_SYNC_NFE_ENTRADA''';
    Q.Open;
    if Q.FieldByName('QTD').AsInteger = 0 then
    begin
      Q.Close;
      Q.SQL.Text :=
        'create table CONFERE_ARQUIVO_SYNC_NFE_ENTRADA (' +
        '  SOURCE_ID integer not null,' +
        '  HASH_INCREMENTO integer not null,' +
        '  PAYLOAD_REV integer default 0,' +
        '  STATUS_OPERACIONAL varchar(40),' +
        '  ULTIMO_ENVIO timestamp,' +
        '  constraint PK_CONFERE_ARQ_SYNC_NFE_ENT primary key (SOURCE_ID)' +
        ')';
      Q.ExecSQL;
      FConnection.Commit;
    end;

    if not SyncColumnExists('PAYLOAD_REV') then
    begin
      Q.Close;
      Q.SQL.Text := 'alter table CONFERE_ARQUIVO_SYNC_NFE_ENTRADA add PAYLOAD_REV integer default 0';
      Q.ExecSQL;
      FConnection.Commit;
    end;
  finally
    Q.Free;
  end;
end;

function TConfereAgentSourceNFeEntrada.Validate(out AMessage: string): Boolean;
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
    Q.SQL.Text := 'select first 1 cod_ent from entradas';
    Q.Open;
    AMessage := 'Banco NFe Entrada validado com sucesso.';
    Result := True;
  except
    on E: Exception do
    begin
      AMessage := E.Message;
      ConfereLogError('Falha validando fonte NFe Entrada: ' + E.Message);
    end;
  end;
  Q.Free;
end;

function TConfereAgentSourceNFeEntrada.LoadEmpresa(out AEmpresa: TConfereEmpresaInfo): Boolean;
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
      'join entradas n on n.cod_emp = e.cod_emp ' +
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

function TConfereAgentSourceNFeEntrada.IsSynced(const AItem: TConfereNFeEntradaRecord): Boolean;
var
  Q: TFDQuery;
begin
  EnsureSyncSchema;
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select hash_incremento, coalesce(payload_rev, 0) payload_rev from CONFERE_ARQUIVO_SYNC_NFE_ENTRADA where source_id = :id';
    Q.ParamByName('id').AsInteger := AItem.SourceID;
    Q.Open;
    if not Q.IsEmpty then
      Result := (Q.FieldByName('HASH_INCREMENTO').AsInteger = AItem.HashIncremento) and
                (Q.FieldByName('PAYLOAD_REV').AsInteger = CONFERE_SYNC_REVISION);
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentSourceNFeEntrada.MarkAsSynced(const ASourceID,
  AHashIncremento: Integer; const AStatusOperacional: string);
var
  Q: TFDQuery;
begin
  EnsureSyncSchema;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'update or insert into CONFERE_ARQUIVO_SYNC_NFE_ENTRADA (source_id, hash_incremento, payload_rev, status_operacional, ultimo_envio) ' +
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

function TConfereAgentSourceNFeEntrada.LoadChangedEntradas(const ALastID,
  AWindowDays: Integer): TArray<TConfereNFeEntradaRecord>;
var
  Q: TFDQuery;
  L: TList<TConfereNFeEntradaRecord>;
  Item: TConfereNFeEntradaRecord;
  HashBase: string;
begin
  Q := TFDQuery.Create(nil);
  L := TList<TConfereNFeEntradaRecord>.Create;
  try
    EnsureConnected;
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select e.cod_ent, e.cod_emp, emp.cnpj_emp, emp.razao_emp, emp.fantasia_emp, emp.insc_emp, emp.regime, ' +
      'e.dataemi_ent, e.dataent_ent, e.tipo_ent, e.numnf_ent, e.serie_ent, e.cod_modelo, ' +
      'e.total_ent, e.acres_ent, e.desc_ent, e.frete_ent, e.icmsfrete_ent, e.base_sub_trib, e.valor_icms_sub, ' +
      'e.total_produtos, e.vl_abat_nt, e.vl_seg, e.vl_out_da, e.vl_bc_icms, e.vl_icms, e.vl_ipi, e.vl_pis, e.vl_cofins, ' +
      'e.vl_pis_st, e.vl_cofins_st, e.vl_st, e.chv_nfe, e.nome_xml, e.web, e.uf, e.ie, e.cnpj, e.cod_for ' +
      'from entradas e ' +
      'join empresa emp on emp.cod_emp = e.cod_emp ' +
      'where ((e.cod_ent > :last_id) or (e.dataemi_ent >= :window_date)) ' +
      'order by e.cod_ent';
    Q.ParamByName('last_id').AsInteger := ALastID;
    Q.ParamByName('window_date').AsDate := IncDay(Date, -AWindowDays);
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(Item, SizeOf(Item), 0);
      Item.SourceID := IntFieldValue(Q.FieldByName('COD_ENT'));
      Item.IDEmpresa := IntFieldValue(Q.FieldByName('COD_EMP'));
      Item.EmpresaCNPJ := Trim(Q.FieldByName('CNPJ_EMP').AsString);
      Item.EmpresaRazaoSocial := Trim(Q.FieldByName('RAZAO_EMP').AsString);
      Item.EmpresaNomeFantasia := Trim(Q.FieldByName('FANTASIA_EMP').AsString);
      Item.EmpresaInscricaoEstadual := Trim(Q.FieldByName('INSC_EMP').AsString);
      Item.EmpresaCRT := Trim(Q.FieldByName('REGIME').AsString);
      Item.DataEmissao := DateFieldValue(Q.FieldByName('DATAEMI_ENT'));
      Item.DataEntrada := DateFieldValue(Q.FieldByName('DATAENT_ENT'));
      Item.TipoEntrada := Trim(Q.FieldByName('TIPO_ENT').AsString);
      Item.NumeroNota := Trim(Q.FieldByName('NUMNF_ENT').AsString);
      Item.SerieNota := Trim(Q.FieldByName('SERIE_ENT').AsString);
      Item.CodigoModelo := IntFieldValue(Q.FieldByName('COD_MODELO'));
      Item.TotalEntrada := CurrencyFieldValue(Q.FieldByName('TOTAL_ENT'));
      Item.Acrescimo := CurrencyFieldValue(Q.FieldByName('ACRES_ENT'));
      Item.Desconto := CurrencyFieldValue(Q.FieldByName('DESC_ENT'));
      Item.Frete := CurrencyFieldValue(Q.FieldByName('FRETE_ENT'));
      Item.ICMSFrete := CurrencyFieldValue(Q.FieldByName('ICMSFRETE_ENT'));
      Item.BaseSubTrib := CurrencyFieldValue(Q.FieldByName('BASE_SUB_TRIB'));
      Item.ValorICMSSub := CurrencyFieldValue(Q.FieldByName('VALOR_ICMS_SUB'));
      Item.TotalProdutos := CurrencyFieldValue(Q.FieldByName('TOTAL_PRODUTOS'));
      Item.ValorAbatimento := CurrencyFieldValue(Q.FieldByName('VL_ABAT_NT'));
      Item.ValorSeguro := CurrencyFieldValue(Q.FieldByName('VL_SEG'));
      Item.ValorOutrasDespesas := CurrencyFieldValue(Q.FieldByName('VL_OUT_DA'));
      Item.BaseICMS := CurrencyFieldValue(Q.FieldByName('VL_BC_ICMS'));
      Item.ValorICMS := CurrencyFieldValue(Q.FieldByName('VL_ICMS'));
      Item.ValorIPI := CurrencyFieldValue(Q.FieldByName('VL_IPI'));
      Item.ValorPIS := CurrencyFieldValue(Q.FieldByName('VL_PIS'));
      Item.ValorCOFINS := CurrencyFieldValue(Q.FieldByName('VL_COFINS'));
      Item.ValorPISST := CurrencyFieldValue(Q.FieldByName('VL_PIS_ST'));
      Item.ValorCOFINSST := CurrencyFieldValue(Q.FieldByName('VL_COFINS_ST'));
      Item.ValorST := CurrencyFieldValue(Q.FieldByName('VL_ST'));
      Item.ChaveAcesso := Trim(Q.FieldByName('CHV_NFE').AsString);
      Item.NomeXML := Trim(Q.FieldByName('NOME_XML').AsString);
      Item.Web := Trim(Q.FieldByName('WEB').AsString);
      Item.UF := Trim(Q.FieldByName('UF').AsString);
      Item.IE := Trim(Q.FieldByName('IE').AsString);
      Item.DocumentoFornecedor := Trim(Q.FieldByName('CNPJ').AsString);
      Item.CodFornecedor := IntFieldValue(Q.FieldByName('COD_FOR'));

      Item.StatusOperacional := ConfereNFeEntradaStatusFromRecord(Item);
      HashBase := Format('%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s',
        [Item.SourceID, Item.IDEmpresa, Item.EmpresaCNPJ, Item.NumeroNota, Item.SerieNota, Item.ChaveAcesso, Item.NomeXML,
         FormatDateTime('yyyy-mm-dd', Item.DataEmissao), FormatFloat('0.00', Item.TotalEntrada),
         FormatFloat('0.00', Item.BaseICMS), FormatFloat('0.00', Item.ValorICMS), Item.DocumentoFornecedor]);
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
