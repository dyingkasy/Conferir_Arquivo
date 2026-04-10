unit Frm_ConfereArquivoAgentMain;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  ConfereArquivo.Agent.Config, ConfereArquivo.Agent.Sync;

type
  TFrmConfereArquivoAgentMain = class(TForm)
    pnlHeader: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    gbOrigem: TGroupBox;
    lblBanco: TLabel;
    lblUsuario: TLabel;
    lblSenha: TLabel;
    edBanco: TEdit;
    edUsuario: TEdit;
    edSenha: TEdit;
    gbServidor: TGroupBox;
    lblApiUrl: TLabel;
    lblToken: TLabel;
    lblInstalacao: TLabel;
    edApiUrl: TEdit;
    edToken: TEdit;
    edInstalacao: TEdit;
    gbAgente: TGroupBox;
    lblIntervalo: TLabel;
    lblJanela: TLabel;
    edtIntervalo: TEdit;
    edtJanela: TEdit;
    chkAtivo: TCheckBox;
    btnSalvar: TButton;
    btnValidarBanco: TButton;
    btnValidarApi: TButton;
    btnColetarAgora: TButton;
    btnSyncTotal: TButton;
    btnIniciar: TButton;
    btnParar: TButton;
    btnAbrirLogs: TButton;
    btnTestarTudo: TButton;
    gbMonitor: TGroupBox;
    lblEmpresa: TLabel;
    lblPendentes: TLabel;
    lblUltimaMsg: TLabel;
    lblUltimaLeitura: TLabel;
    edEmpresa: TEdit;
    edPendentes: TEdit;
    edUltimaMensagem: TEdit;
    edUltimaLeitura: TEdit;
    mmEventos: TMemo;
    tmrAgente: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnValidarBancoClick(Sender: TObject);
    procedure btnValidarApiClick(Sender: TObject);
    procedure btnColetarAgoraClick(Sender: TObject);
    procedure btnSyncTotalClick(Sender: TObject);
    procedure btnIniciarClick(Sender: TObject);
    procedure btnPararClick(Sender: TObject);
    procedure btnAbrirLogsClick(Sender: TObject);
    procedure btnTestarTudoClick(Sender: TObject);
    procedure tmrAgenteTimer(Sender: TObject);
  private
    FConfig: TConfereAgentConfig;
    FEngine: TConfereSyncEngine;
    FBusy: Boolean;
    procedure LoadScreen;
    procedure SaveScreenToConfig;
    procedure RecreateEngine;
    procedure AppendEvent(const AText: string);
    procedure RefreshMonitor;
    procedure RunPoll;
    function ReadLastOperationalLines: string;
  public
  end;

var
  FrmConfereArquivoAgentMain: TFrmConfereArquivoAgentMain;

implementation

{$R *.dfm}

uses
  System.IOUtils, ConfereArquivo.Logger;

procedure TFrmConfereArquivoAgentMain.FormCreate(Sender: TObject);
begin
  Caption := 'Confere Arquivo - Agente Local';
  LoadAgentConfig(FConfig);
  ConfigureConfereLogger(FConfig.LogPath);
  LoadScreen;
  RecreateEngine;
  AppendEvent('Agente carregado.');
end;

procedure TFrmConfereArquivoAgentMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FEngine);
end;

procedure TFrmConfereArquivoAgentMain.LoadScreen;
begin
  edBanco.Text := FConfig.SourceDatabasePath;
  edUsuario.Text := FConfig.FirebirdUser;
  edSenha.Text := FConfig.FirebirdPassword;
  edApiUrl.Text := FConfig.ApiBaseUrl;
  edToken.Text := FConfig.ApiToken;
  edInstalacao.Text := FConfig.InstalacaoID;
  edtIntervalo.Text := FConfig.IntervalSeconds.ToString;
  edtJanela.Text := FConfig.WindowDays.ToString;
  chkAtivo.Checked := FConfig.Enabled;
  edEmpresa.Text := '';
  edPendentes.Text := '0';
  edUltimaMensagem.Text := '';
  edUltimaLeitura.Text := '';
  mmEventos.Lines.Text := ReadLastOperationalLines;
end;

procedure TFrmConfereArquivoAgentMain.SaveScreenToConfig;
begin
  FConfig.SourceDatabasePath := Trim(edBanco.Text);
  FConfig.FirebirdUser := Trim(edUsuario.Text);
  FConfig.FirebirdPassword := edSenha.Text;
  FConfig.ApiBaseUrl := Trim(edApiUrl.Text);
  FConfig.ApiToken := Trim(edToken.Text);
  FConfig.InstalacaoID := Trim(edInstalacao.Text);
  FConfig.IntervalSeconds := StrToIntDef(Trim(edtIntervalo.Text), 15);
  if FConfig.IntervalSeconds <= 0 then
    FConfig.IntervalSeconds := 15;
  FConfig.WindowDays := StrToIntDef(Trim(edtJanela.Text), 3);
  if FConfig.WindowDays <= 0 then
    FConfig.WindowDays := 3;
  FConfig.Enabled := chkAtivo.Checked;
  SaveAgentConfig(FConfig);
end;

procedure TFrmConfereArquivoAgentMain.RecreateEngine;
begin
  FreeAndNil(FEngine);
  FEngine := TConfereSyncEngine.Create(FConfig);
  tmrAgente.Enabled := False;
  tmrAgente.Interval := FConfig.IntervalSeconds * 1000;
end;

procedure TFrmConfereArquivoAgentMain.AppendEvent(const AText: string);
begin
  mmEventos.Lines.Add(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + '  ' + AText);
  mmEventos.Perform(EM_LINESCROLL, 0, mmEventos.Lines.Count);
end;

procedure TFrmConfereArquivoAgentMain.RefreshMonitor;
begin
  if Assigned(FEngine) then
  begin
    try
      edEmpresa.Text := FEngine.EmpresaResumo;
    except
      edEmpresa.Text := '';
    end;
    edPendentes.Text := FEngine.PendingCount.ToString;
    edUltimaMensagem.Text := FEngine.LastMessage;
  end;
  edUltimaLeitura.Text := FormatDateTime('dd/mm/yyyy hh:nn:ss', Now);
end;

function TFrmConfereArquivoAgentMain.ReadLastOperationalLines: string;
var
  FileName: string;
  Lines: TStringList;
  I, StartIdx: Integer;
begin
  Result := '';
  FileName := IncludeTrailingPathDelimiter(FConfig.LogPath) +
    'operacional_' + FormatDateTime('yyyymmdd', Date) + '.log';
  if not FileExists(FileName) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName, TEncoding.UTF8);
    StartIdx := Max(Lines.Count - 20, 0);
    for I := StartIdx to Lines.Count - 1 do
      Result := Result + Lines[I] + sLineBreak;
  finally
    Lines.Free;
  end;
end;

procedure TFrmConfereArquivoAgentMain.RunPoll;
begin
  if FBusy or not Assigned(FEngine) then
    Exit;

  FBusy := True;
  try
    FEngine.PollNow;
    AppendEvent(FEngine.LastMessage);
    RefreshMonitor;
  except
    on E: Exception do
    begin
      AppendEvent('Falha na coleta: ' + E.Message);
      edUltimaMensagem.Text := E.Message;
    end;
  end;
  FBusy := False;
end;

procedure TFrmConfereArquivoAgentMain.btnSalvarClick(Sender: TObject);
begin
  SaveScreenToConfig;
  RecreateEngine;
  AppendEvent('Configuracao salva.');
end;

procedure TFrmConfereArquivoAgentMain.btnValidarBancoClick(Sender: TObject);
var
  Msg: string;
begin
  SaveScreenToConfig;
  RecreateEngine;
  if FEngine.Validate(Msg) then
    AppendEvent(Msg)
  else
    AppendEvent('Falha no banco: ' + Msg);
end;

procedure TFrmConfereArquivoAgentMain.btnValidarApiClick(Sender: TObject);
var
  Msg: string;
begin
  SaveScreenToConfig;
  RecreateEngine;
  if FEngine.ValidateApi(Msg) then
    AppendEvent(Msg)
  else
    AppendEvent('Falha API: ' + Msg);
end;

procedure TFrmConfereArquivoAgentMain.btnColetarAgoraClick(Sender: TObject);
begin
  SaveScreenToConfig;
  RecreateEngine;
  RunPoll;
end;

procedure TFrmConfereArquivoAgentMain.btnSyncTotalClick(Sender: TObject);
begin
  SaveScreenToConfig;
  RecreateEngine;
  try
    FEngine.SyncTotal;
    AppendEvent(FEngine.LastMessage);
    RefreshMonitor;
  except
    on E: Exception do
      AppendEvent('Falha no sync total: ' + E.Message);
  end;
end;

procedure TFrmConfereArquivoAgentMain.btnIniciarClick(Sender: TObject);
begin
  SaveScreenToConfig;
  RecreateEngine;
  tmrAgente.Interval := FConfig.IntervalSeconds * 1000;
  tmrAgente.Enabled := True;
  AppendEvent('Agente automatico iniciado.');
end;

procedure TFrmConfereArquivoAgentMain.btnPararClick(Sender: TObject);
begin
  tmrAgente.Enabled := False;
  AppendEvent('Agente automatico parado.');
end;

procedure TFrmConfereArquivoAgentMain.btnAbrirLogsClick(Sender: TObject);
begin
  ShellExecute(Handle, 'open', PChar(FConfig.LogPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TFrmConfereArquivoAgentMain.btnTestarTudoClick(Sender: TObject);
begin
  btnValidarBancoClick(Sender);
  btnValidarApiClick(Sender);
  btnColetarAgoraClick(Sender);
end;

procedure TFrmConfereArquivoAgentMain.tmrAgenteTimer(Sender: TObject);
begin
  RunPoll;
end;

end.
