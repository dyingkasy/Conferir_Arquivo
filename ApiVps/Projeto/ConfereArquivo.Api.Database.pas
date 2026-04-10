unit ConfereArquivo.Api.Database;

interface

uses
  System.SysUtils, System.JSON, FireDAC.Comp.Client,
  ConfereArquivo.Api.Config;

type
  TConfereApiDatabase = class
  private
    FConfig: TConfereApiConfig;
    FConnection: TFDConnection;
    procedure EnsureConnected;
    function JsonNumberToCurrency(const AValue: TJSONValue): Currency;
  public
    constructor Create(const AConfig: TConfereApiConfig);
    destructor Destroy; override;
    procedure EnsureSchema;
    function ValidateConnection(out AMessage: string): Boolean;
    function RegisterOrValidateTenant(const ACNPJ, AToken, ARazaoSocial: string): Boolean;
    procedure SaveHeartbeat(const ACNPJ, AInstalacaoID, ARemoteIP: string);
    procedure SaveLote(const ALote: TJSONObject; const AToken, ARemoteIP: string);
  end;

implementation

uses
  Data.DB, System.DateUtils, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.Phys, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef;

constructor TConfereApiDatabase.Create(const AConfig: TConfereApiConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FConnection := TFDConnection.Create(nil);
  FConnection.LoginPrompt := False;
  FConnection.Params.DriverID := 'PG';
  FConnection.Params.Database := FConfig.PgDatabase;
  FConnection.Params.UserName := FConfig.PgUser;
  FConnection.Params.Password := FConfig.PgPassword;
  FConnection.Params.Values['Server'] := FConfig.PgHost;
  FConnection.Params.Values['Port'] := FConfig.PgPort.ToString;
end;

destructor TConfereApiDatabase.Destroy;
begin
  FConnection.Free;
  inherited Destroy;
end;

procedure TConfereApiDatabase.EnsureConnected;
begin
  if not FConnection.Connected then
    FConnection.Connected := True;
end;

function TConfereApiDatabase.ValidateConnection(out AMessage: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  AMessage := '';
  Q := TFDQuery.Create(nil);
  try
    EnsureConnected;
    Q.Connection := FConnection;
    Q.SQL.Text := 'select 1';
    Q.Open;
    Result := True;
    AMessage := 'PostgreSQL validado.';
  finally
    Q.Free;
  end;
end;

procedure TConfereApiDatabase.EnsureSchema;
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'create table if not exists tenant_empresa (' +
      '  cnpj varchar(14) primary key,' +
      '  api_token varchar(200) not null,' +
      '  razao_social varchar(200),' +
      '  ativo boolean not null default true,' +
      '  created_at timestamp not null default current_timestamp,' +
      '  updated_at timestamp not null default current_timestamp' +
      ')';
    Q.ExecSQL;

    Q.SQL.Text :=
      'create table if not exists agente_instalacao (' +
      '  instalacao_id varchar(80) primary key,' +
      '  cnpj_empresa varchar(14) not null,' +
      '  remote_ip varchar(60),' +
      '  last_seen_at timestamp not null default current_timestamp,' +
      '  created_at timestamp not null default current_timestamp' +
      ')';
    Q.ExecSQL;

    Q.SQL.Text :=
      'create table if not exists nfce_sync_lote (' +
      '  id bigserial primary key,' +
      '  cnpj_empresa varchar(14) not null,' +
      '  instalacao_id varchar(80),' +
      '  quantidade integer not null,' +
      '  remote_ip varchar(60),' +
      '  raw_json jsonb not null,' +
      '  created_at timestamp not null default current_timestamp' +
      ')';
    Q.ExecSQL;

    Q.SQL.Text :=
      'create table if not exists nfce_cabecalho_espelho (' +
      '  id bigserial primary key,' +
      '  cnpj_empresa varchar(14) not null,' +
      '  source_id integer not null,' +
      '  instalacao_id varchar(80),' +
      '  id_ecf_movimento integer,' +
      '  data_venda date,' +
      '  hora_venda varchar(8),' +
      '  status_venda varchar(5),' +
      '  num_nfce integer,' +
      '  serie_nfce integer,' +
      '  chave_acesso varchar(200),' +
      '  protocolo varchar(150),' +
      '  nfce_cancelada varchar(5),' +
      '  nfce_offline varchar(5),' +
      '  codigo_numerico_nfce integer,' +
      '  caminho_xml varchar(400),' +
      '  status_erro varchar(300),' +
      '  dhcont varchar(30),' +
      '  data_autorizacao date,' +
      '  valor_venda numeric(18,6),' +
      '  valor_final numeric(18,6),' +
      '  total_produtos numeric(18,6),' +
      '  total_documento numeric(18,6),' +
      '  base_icms numeric(18,6),' +
      '  icms numeric(18,6),' +
      '  pis numeric(18,6),' +
      '  cofins numeric(18,6),' +
      '  imposto numeric(18,6),' +
      '  imposto_estadual numeric(18,6),' +
      '  documento_cliente varchar(20),' +
      '  nome_cliente varchar(150),' +
      '  hash_incremento integer,' +
      '  status_operacional varchar(40),' +
      '  payload_json jsonb not null,' +
      '  remote_ip varchar(60),' +
      '  updated_at timestamp not null default current_timestamp,' +
      '  created_at timestamp not null default current_timestamp,' +
      '  constraint uq_nfce_espelho unique(cnpj_empresa, source_id)' +
      ')';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TConfereApiDatabase.RegisterOrValidateTenant(const ACNPJ, AToken,
  ARazaoSocial: string): Boolean;
var
  Q: TFDQuery;
  DbToken: string;
begin
  Result := False;
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'select api_token from tenant_empresa where cnpj = :cnpj';
    Q.ParamByName('cnpj').AsString := ACNPJ;
    Q.Open;
    if Q.IsEmpty then
    begin
      Q.Close;
      Q.SQL.Text :=
        'insert into tenant_empresa(cnpj, api_token, razao_social, created_at, updated_at) ' +
        'values (:cnpj, :token, :razao, current_timestamp, current_timestamp)';
      Q.ParamByName('cnpj').AsString := ACNPJ;
      Q.ParamByName('token').AsString := AToken;
      Q.ParamByName('razao').AsString := Copy(ARazaoSocial, 1, 200);
      Q.ExecSQL;
      Exit(True);
    end;

    DbToken := Trim(Q.FieldByName('api_token').AsString);
    Result := SameText(DbToken, Trim(AToken));
  finally
    Q.Free;
  end;
end;

procedure TConfereApiDatabase.SaveHeartbeat(const ACNPJ, AInstalacaoID,
  ARemoteIP: string);
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'insert into agente_instalacao(instalacao_id, cnpj_empresa, remote_ip, last_seen_at, created_at) ' +
      'values (:id, :cnpj, :ip, current_timestamp, current_timestamp) ' +
      'on conflict (instalacao_id) do update set cnpj_empresa = excluded.cnpj_empresa, remote_ip = excluded.remote_ip, last_seen_at = current_timestamp';
    Q.ParamByName('id').AsString := AInstalacaoID;
    Q.ParamByName('cnpj').AsString := ACNPJ;
    Q.ParamByName('ip').AsString := Copy(ARemoteIP, 1, 60);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TConfereApiDatabase.JsonNumberToCurrency(const AValue: TJSONValue): Currency;
begin
  if not Assigned(AValue) then
    Exit(0);

  Result := StrToCurrDef(StringReplace(AValue.Value, '.', ',', [rfReplaceAll]), 0);
end;

procedure TConfereApiDatabase.SaveLote(const ALote: TJSONObject; const AToken,
  ARemoteIP: string);
var
  CNPJ, InstalacaoID, RazaoSocial: string;
  Quantidade: Integer;
  Notas: TJSONArray;
  NotaObj, EmpresaObj, VendaObj: TJSONObject;
  Q: TFDQuery;
  I: Integer;
  DataVendaValue, DataAutValue: string;
begin
  CNPJ := ALote.GetValue<string>('cnpj_empresa', '');
  InstalacaoID := ALote.GetValue<string>('instalacao_id', '');
  Quantidade := ALote.GetValue<Integer>('quantidade', 0);
  Notas := ALote.GetValue<TJSONArray>('notas');
  if not Assigned(Notas) then
    raise Exception.Create('Lote sem notas.');

  if not RegisterOrValidateTenant(CNPJ, AToken, '') then
    raise Exception.Create('Token invalido para o CNPJ informado.');

  SaveHeartbeat(CNPJ, InstalacaoID, ARemoteIP);

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'insert into nfce_sync_lote(cnpj_empresa, instalacao_id, quantidade, remote_ip, raw_json) ' +
      'values (:cnpj, :inst, :qtd, :ip, cast(:raw as jsonb))';
    Q.ParamByName('cnpj').AsString := CNPJ;
    Q.ParamByName('inst').AsString := InstalacaoID;
    Q.ParamByName('qtd').AsInteger := Quantidade;
    Q.ParamByName('ip').AsString := Copy(ARemoteIP, 1, 60);
    Q.ParamByName('raw').AsString := ALote.ToJSON;
    Q.ExecSQL;

    for I := 0 to Notas.Count - 1 do
    begin
      NotaObj := Notas.Items[I] as TJSONObject;
      EmpresaObj := NotaObj.GetValue<TJSONObject>('empresa');
      VendaObj := NotaObj.GetValue<TJSONObject>('venda');
      if not Assigned(VendaObj) then
        Continue;

      RazaoSocial := '';
      if Assigned(EmpresaObj) then
        RazaoSocial := EmpresaObj.GetValue<string>('razao_social', '');
      RegisterOrValidateTenant(CNPJ, AToken, RazaoSocial);

      DataVendaValue := VendaObj.GetValue<string>('data_venda', '');
      DataAutValue := VendaObj.GetValue<string>('data_autorizacao', '');

      Q.SQL.Text :=
        'insert into nfce_cabecalho_espelho(' +
        'cnpj_empresa, source_id, instalacao_id, id_ecf_movimento, data_venda, hora_venda, status_venda, ' +
        'num_nfce, serie_nfce, chave_acesso, protocolo, nfce_cancelada, nfce_offline, codigo_numerico_nfce, caminho_xml, ' +
        'status_erro, dhcont, data_autorizacao, valor_venda, valor_final, total_produtos, total_documento, base_icms, icms, pis, cofins, ' +
        'imposto, imposto_estadual, documento_cliente, nome_cliente, hash_incremento, status_operacional, payload_json, remote_ip, updated_at, created_at) ' +
        'values (' +
        ':cnpj, :source_id, :inst, :mov, :data_venda, :hora_venda, :status_venda, :num_nfce, :serie_nfce, :chave, :protocolo, :cancelada, :offline, ' +
        ':codigo_numerico, :caminho_xml, :status_erro, :dhcont, :data_autorizacao, :valor_venda, :valor_final, :total_produtos, :total_documento, :base_icms, :icms, :pis, :cofins, ' +
        ':imposto, :imposto_estadual, :documento_cliente, :nome_cliente, :hash_incremento, :status_operacional, cast(:payload as jsonb), :remote_ip, current_timestamp, current_timestamp) ' +
        'on conflict (cnpj_empresa, source_id) do update set ' +
        'instalacao_id = excluded.instalacao_id, id_ecf_movimento = excluded.id_ecf_movimento, data_venda = excluded.data_venda, hora_venda = excluded.hora_venda, ' +
        'status_venda = excluded.status_venda, num_nfce = excluded.num_nfce, serie_nfce = excluded.serie_nfce, chave_acesso = excluded.chave_acesso, protocolo = excluded.protocolo, ' +
        'nfce_cancelada = excluded.nfce_cancelada, nfce_offline = excluded.nfce_offline, codigo_numerico_nfce = excluded.codigo_numerico_nfce, caminho_xml = excluded.caminho_xml, ' +
        'status_erro = excluded.status_erro, dhcont = excluded.dhcont, data_autorizacao = excluded.data_autorizacao, valor_venda = excluded.valor_venda, valor_final = excluded.valor_final, ' +
        'total_produtos = excluded.total_produtos, total_documento = excluded.total_documento, base_icms = excluded.base_icms, icms = excluded.icms, pis = excluded.pis, cofins = excluded.cofins, ' +
        'imposto = excluded.imposto, imposto_estadual = excluded.imposto_estadual, documento_cliente = excluded.documento_cliente, nome_cliente = excluded.nome_cliente, hash_incremento = excluded.hash_incremento, ' +
        'status_operacional = excluded.status_operacional, payload_json = excluded.payload_json, remote_ip = excluded.remote_ip, updated_at = current_timestamp';

      Q.ParamByName('cnpj').AsString := CNPJ;
      Q.ParamByName('source_id').AsInteger := VendaObj.GetValue<Integer>('source_id', 0);
      Q.ParamByName('inst').AsString := InstalacaoID;
      Q.ParamByName('mov').AsInteger := VendaObj.GetValue<Integer>('id_ecf_movimento', 0);
      if DataVendaValue <> '' then
        Q.ParamByName('data_venda').AsDate := ISO8601ToDate(DataVendaValue)
      else
        Q.ParamByName('data_venda').Clear;
      Q.ParamByName('hora_venda').AsString := VendaObj.GetValue<string>('hora_venda', '');
      Q.ParamByName('status_venda').AsString := VendaObj.GetValue<string>('status_venda', '');
      Q.ParamByName('num_nfce').AsInteger := VendaObj.GetValue<Integer>('num_nfce', 0);
      Q.ParamByName('serie_nfce').AsInteger := VendaObj.GetValue<Integer>('serie_nfce', 0);
      Q.ParamByName('chave').AsString := VendaObj.GetValue<string>('chave_acesso', '');
      Q.ParamByName('protocolo').AsString := VendaObj.GetValue<string>('protocolo', '');
      Q.ParamByName('cancelada').AsString := VendaObj.GetValue<string>('nfce_cancelada', '');
      Q.ParamByName('offline').AsString := VendaObj.GetValue<string>('nfce_offline', '');
      Q.ParamByName('codigo_numerico').AsInteger := VendaObj.GetValue<Integer>('codigo_numerico_nfce', 0);
      Q.ParamByName('caminho_xml').AsString := VendaObj.GetValue<string>('caminho_xml', '');
      Q.ParamByName('status_erro').AsString := Copy(VendaObj.GetValue<string>('status_erro', ''), 1, 300);
      Q.ParamByName('dhcont').AsString := VendaObj.GetValue<string>('dhcont', '');
      if DataAutValue <> '' then
        Q.ParamByName('data_autorizacao').AsDate := ISO8601ToDate(DataAutValue)
      else
        Q.ParamByName('data_autorizacao').Clear;
      Q.ParamByName('valor_venda').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('valor_venda'));
      Q.ParamByName('valor_final').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('valor_final'));
      Q.ParamByName('total_produtos').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('total_produtos'));
      Q.ParamByName('total_documento').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('total_documento'));
      Q.ParamByName('base_icms').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('base_icms'));
      Q.ParamByName('icms').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('icms'));
      Q.ParamByName('pis').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('pis'));
      Q.ParamByName('cofins').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('cofins'));
      Q.ParamByName('imposto').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('imposto'));
      Q.ParamByName('imposto_estadual').AsCurrency := JsonNumberToCurrency(VendaObj.GetValue('imposto_estadual'));
      Q.ParamByName('documento_cliente').AsString := VendaObj.GetValue<string>('documento_cliente', '');
      Q.ParamByName('nome_cliente').AsString := Copy(VendaObj.GetValue<string>('nome_cliente', ''), 1, 150);
      Q.ParamByName('hash_incremento').AsInteger := VendaObj.GetValue<Integer>('hash_incremento', 0);
      Q.ParamByName('status_operacional').AsString := VendaObj.GetValue<string>('status_operacional', '');
      Q.ParamByName('payload').AsString := NotaObj.ToJSON;
      Q.ParamByName('remote_ip').AsString := Copy(ARemoteIP, 1, 60);
      Q.ExecSQL;
    end;
  finally
    Q.Free;
  end;
end;

end.
