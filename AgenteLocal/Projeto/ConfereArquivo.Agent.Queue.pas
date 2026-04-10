unit ConfereArquivo.Agent.Queue;

interface

uses
  System.SysUtils, FireDAC.Comp.Client,
  ConfereArquivo.Types;

type
  TConfereAgentQueue = class
  private
    FDatabasePath: string;
    FConnection: TFDConnection;
    procedure EnsureConnected;
    function ExecuteScalarInt(const ASQL: string; AParamName: string = ''; AParamValue: Integer = 0): Integer;
  public
    constructor Create(const ADatabasePath: string);
    destructor Destroy; override;
    procedure EnsureSchema;
    function GetStateInt(const AKey: string; ADefault: Integer): Integer;
    procedure SetStateInt(const AKey: string; const AValue: Integer);
    function ShouldEnqueue(const AItem: TConfereNFCeRecord): Boolean;
    procedure Enqueue(const AItem: TConfereNFCeRecord; const APayloadJson: string);
    function GetPending(const ALimit: Integer): TArray<TConfereQueueItem>;
    procedure MarkSent(const AQueueID: Integer);
    procedure MarkFailed(const AQueueID: Integer; const AError: string);
    function PendingCount: Integer;
    procedure ResetFullSync;
  end;

implementation

uses
  System.Generics.Collections, Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, ConfereArquivo.Logger, ConfereArquivo.Json;

constructor TConfereAgentQueue.Create(const ADatabasePath: string);
begin
  inherited Create;
  FDatabasePath := ADatabasePath;
  FConnection := TFDConnection.Create(nil);
  FConnection.LoginPrompt := False;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FDatabasePath;
  FConnection.Params.Values['LockingMode'] := 'Normal';
end;

destructor TConfereAgentQueue.Destroy;
begin
  FreeAndNil(FConnection);
  inherited Destroy;
end;

procedure TConfereAgentQueue.EnsureConnected;
begin
  if not FConnection.Connected then
    FConnection.Connected := True;
end;

procedure TConfereAgentQueue.EnsureSchema;
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'create table if not exists sync_state (' +
      '  key_name text primary key,' +
      '  int_value integer,' +
      '  updated_at text' +
      ');';
    Q.ExecSQL;

    Q.SQL.Text :=
      'create table if not exists nfce_snapshot (' +
      '  source_id integer primary key,' +
      '  hash_incremento integer not null,' +
      '  status_operacional text,' +
      '  updated_at text' +
      ');';
    Q.ExecSQL;

    Q.SQL.Text :=
      'create table if not exists outbound_queue (' +
      '  id integer primary key autoincrement,' +
      '  source_id integer not null,' +
      '  payload_json text not null,' +
      '  send_attempts integer default 0,' +
      '  created_at text not null,' +
      '  sent_at text,' +
      '  last_error text' +
      ');';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TConfereAgentQueue.ExecuteScalarInt(const ASQL: string; AParamName: string;
  AParamValue: Integer): Integer;
var
  Q: TFDQuery;
begin
  Result := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := ASQL;
    if AParamName <> '' then
      Q.ParamByName(AParamName).AsInteger := AParamValue;
    Q.Open;
    if not Q.IsEmpty then
      Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

function TConfereAgentQueue.GetStateInt(const AKey: string; ADefault: Integer): Integer;
var
  Q: TFDQuery;
begin
  Result := ADefault;
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'select int_value from sync_state where key_name = :k';
    Q.ParamByName('k').AsString := AKey;
    Q.Open;
    if not Q.IsEmpty then
      Result := Q.FieldByName('int_value').AsInteger;
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentQueue.SetStateInt(const AKey: string; const AValue: Integer);
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'insert or replace into sync_state(key_name, int_value, updated_at) values (:k, :v, :u)';
    Q.ParamByName('k').AsString := AKey;
    Q.ParamByName('v').AsInteger := AValue;
    Q.ParamByName('u').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TConfereAgentQueue.ShouldEnqueue(const AItem: TConfereNFCeRecord): Boolean;
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Result := True;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'select hash_incremento from nfce_snapshot where source_id = :id';
    Q.ParamByName('id').AsInteger := AItem.SourceID;
    Q.Open;
    if not Q.IsEmpty then
      Result := Q.FieldByName('hash_incremento').AsInteger <> AItem.HashIncremento;
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentQueue.Enqueue(const AItem: TConfereNFCeRecord;
  const APayloadJson: string);
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;

    Q.SQL.Text :=
      'insert into outbound_queue(source_id, payload_json, send_attempts, created_at) ' +
      'values (:source_id, :payload_json, 0, :created_at)';
    Q.ParamByName('source_id').AsInteger := AItem.SourceID;
    Q.ParamByName('payload_json').AsString := APayloadJson;
    Q.ParamByName('created_at').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ExecSQL;

    Q.SQL.Text :=
      'insert or replace into nfce_snapshot(source_id, hash_incremento, status_operacional, updated_at) ' +
      'values (:source_id, :hash_incremento, :status_operacional, :updated_at)';
    Q.ParamByName('source_id').AsInteger := AItem.SourceID;
    Q.ParamByName('hash_incremento').AsInteger := AItem.HashIncremento;
    Q.ParamByName('status_operacional').AsString := ConfereStatusToString(AItem.StatusOperacional);
    Q.ParamByName('updated_at').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TConfereAgentQueue.GetPending(const ALimit: Integer): TArray<TConfereQueueItem>;
var
  Q: TFDQuery;
  L: TList<TConfereQueueItem>;
  Item: TConfereQueueItem;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  L := TList<TConfereQueueItem>.Create;
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'select id, source_id, payload_json, send_attempts ' +
      'from outbound_queue where sent_at is null order by id limit :lim';
    Q.ParamByName('lim').AsInteger := ALimit;
    Q.Open;
    while not Q.Eof do
    begin
      Item.QueueID := Q.FieldByName('id').AsInteger;
      Item.SourceID := Q.FieldByName('source_id').AsInteger;
      Item.PayloadJson := Q.FieldByName('payload_json').AsString;
      Item.Attempts := Q.FieldByName('send_attempts').AsInteger;
      L.Add(Item);
      Q.Next;
    end;
    Result := L.ToArray;
  finally
    L.Free;
    Q.Free;
  end;
end;

procedure TConfereAgentQueue.MarkSent(const AQueueID: Integer);
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'update outbound_queue set sent_at = :s where id = :id';
    Q.ParamByName('s').AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Q.ParamByName('id').AsInteger := AQueueID;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TConfereAgentQueue.MarkFailed(const AQueueID: Integer; const AError: string);
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'update outbound_queue set send_attempts = coalesce(send_attempts,0) + 1, last_error = :e where id = :id';
    Q.ParamByName('e').AsString := Copy(AError, 1, 500);
    Q.ParamByName('id').AsInteger := AQueueID;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TConfereAgentQueue.PendingCount: Integer;
begin
  EnsureConnected;
  Result := ExecuteScalarInt('select count(*) from outbound_queue where sent_at is null');
end;

procedure TConfereAgentQueue.ResetFullSync;
var
  Q: TFDQuery;
begin
  EnsureConnected;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'delete from outbound_queue';
    Q.ExecSQL;
    Q.SQL.Text := 'delete from nfce_snapshot';
    Q.ExecSQL;
    Q.SQL.Text := 'delete from sync_state where key_name = :k';
    Q.ParamByName('k').AsString := 'last_cursor';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

end.
