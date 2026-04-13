unit Frm_ConfereArquivoAgentMain;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.Math, System.DateUtils,
  System.Types, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus,
  ConfereArquivo.Agent.Config, ConfereArquivo.Agent.Sync;

type
  TFrmConfereArquivoAgentMain = class(TForm)
    pnlHeader: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    gbOrigem: TGroupBox;
    lblBancoNFCe: TLabel;
    lblBancoNFeSaida: TLabel;
    chkAtivarNFCe: TCheckBox;
    chkAtivarNFeSaida: TCheckBox;
    lblUsuario: TLabel;
    lblSenha: TLabel;
    mmBancosNFCe: TMemo;
    mmBancosNFeSaida: TMemo;
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
    chkIniciarWindows: TCheckBox;
    btnSalvar: TButton;
    btnValidarBanco: TButton;
    btnValidarApi: TButton;
    btnSyncTotal: TButton;
    btnParar: TButton;
    btnAbrirLogs: TButton;
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
    tmrTrayCountdown: TTimer;
    TrayPopup: TPopupMenu;
    miStatus: TMenuItem;
    miProximaSync: TMenuItem;
    N1: TMenuItem;
    miAbrir: TMenuItem;
    miSair: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnValidarBancoClick(Sender: TObject);
    procedure btnValidarApiClick(Sender: TObject);
    procedure btnSyncTotalClick(Sender: TObject);
    procedure btnPararClick(Sender: TObject);
    procedure btnAbrirLogsClick(Sender: TObject);
    procedure tmrAgenteTimer(Sender: TObject);
    procedure tmrTrayCountdownTimer(Sender: TObject);
    procedure miAbrirClick(Sender: TObject);
    procedure miSairClick(Sender: TObject);
  private
    const WM_TRAYICON = WM_USER + 101;
  private
    FConfig: TConfereAgentConfig;
    FEngine: TConfereSyncEngine;
    FBusy: Boolean;
    FForceExit: Boolean;
    FNextSyncAt: TDateTime;
    FTrayData: TNotifyIconData;
    procedure ApplyVisualStyle;
    procedure StyleReadOnlyEdit(AEdit: TEdit; const AColor: TColor);
    procedure StyleButton(AButton: TButton);
    procedure AddTrayIcon;
    procedure RemoveTrayIcon;
    procedure ShowTrayBalloon(const ATitle, AText: string);
    procedure HideToTray(const AMessage: string);
    procedure ShowFromTray;
    procedure UpdateTrayMenu;
    procedure ScheduleNextSync;
    procedure WMTrayIcon(var Msg: TMessage); message WM_TRAYICON;
    procedure LoadScreen;
    procedure SaveScreenToConfig;
    procedure RecreateEngine;
    procedure AppendEvent(const AText: string);
    procedure RefreshMonitor;
    procedure RunPoll;
    procedure StartAutomaticSync;
    function ParseMemoPaths(AMemo: TMemo): TStringDynArray;
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
var
  StartHidden: Boolean;
begin
  Caption := 'Confere Arquivo - Agente Local';
  LoadAgentConfig(FConfig);
  ConfigureConfereLogger(FConfig.LogPath);
  LoadScreen;
  ApplyVisualStyle;
  RecreateEngine;
  AddTrayIcon;
  AppendEvent('Agente carregado.');
  if FConfig.FirstRunPending then
    AppendEvent('Primeira abertura detectada. A sincronizacao automatica permanece parada ate voce salvar a configuracao ou executar um Sync Total.')
  else if FConfig.Enabled then
    StartAutomaticSync;

  StartHidden := FindCmdLineSwitch('tray', ['-', '/'], True);
  if StartHidden then
    HideToTray('Agente iniciado com o Windows. Coleta automatica ativa para NFC-e e NFe Saida.');
end;

procedure TFrmConfereArquivoAgentMain.FormDestroy(Sender: TObject);
begin
  RemoveTrayIcon;
  FreeAndNil(FEngine);
end;

procedure TFrmConfereArquivoAgentMain.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if FForceExit then
    Exit;
  Action := caNone;
  HideToTray('O agente continua ativo na bandeja do Windows.');
end;

procedure TFrmConfereArquivoAgentMain.FormResize(Sender: TObject);
begin
  if WindowState = wsMinimized then
    HideToTray('O agente foi minimizado para a bandeja.');
end;

procedure TFrmConfereArquivoAgentMain.StyleReadOnlyEdit(AEdit: TEdit; const AColor: TColor);
begin
  AEdit.Color := AColor;
  AEdit.Font.Color := $00342E25;
  AEdit.Font.Style := [fsBold];
  AEdit.ReadOnly := True;
end;

procedure TFrmConfereArquivoAgentMain.StyleButton(AButton: TButton);
begin
  AButton.Font.Style := [fsBold];
end;

procedure TFrmConfereArquivoAgentMain.ApplyVisualStyle;
begin
  Color := $00F4F6F8;
  gbOrigem.Font.Style := [fsBold];
  gbServidor.Font.Style := [fsBold];
  gbAgente.Font.Style := [fsBold];
  gbMonitor.Font.Style := [fsBold];
  StyleButton(btnSalvar);
  StyleButton(btnValidarBanco);
  StyleButton(btnValidarApi);
  StyleButton(btnSyncTotal);
  StyleButton(btnParar);
  StyleButton(btnAbrirLogs);
  StyleReadOnlyEdit(edEmpresa, $00EAF0F7);
  StyleReadOnlyEdit(edPendentes, $00FFF0D9);
  StyleReadOnlyEdit(edUltimaMensagem, $00F2F4F7);
  StyleReadOnlyEdit(edUltimaLeitura, $00E6F5E8);
  mmEventos.Color := clWhite;
  mmEventos.Font.Name := 'Consolas';
  mmEventos.Font.Height := -11;
  miStatus.Enabled := False;
  miProximaSync.Enabled := False;
  tmrTrayCountdown.Interval := 1000;
  tmrTrayCountdown.Enabled := True;
  UpdateTrayMenu;
end;

procedure TFrmConfereArquivoAgentMain.AddTrayIcon;
begin
  ZeroMemory(@FTrayData, SizeOf(FTrayData));
  FTrayData.cbSize := SizeOf(FTrayData);
  FTrayData.Wnd := Handle;
  FTrayData.uID := 1;
  FTrayData.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
  FTrayData.uCallbackMessage := WM_TRAYICON;
  FTrayData.hIcon := Application.Icon.Handle;
  StrPLCopy(FTrayData.szTip, 'Confere Arquivo - Agente Local', Length(FTrayData.szTip) - 1);
  Shell_NotifyIcon(NIM_ADD, @FTrayData);
end;

procedure TFrmConfereArquivoAgentMain.RemoveTrayIcon;
begin
  if FTrayData.Wnd <> 0 then
    Shell_NotifyIcon(NIM_DELETE, @FTrayData);
  ZeroMemory(@FTrayData, SizeOf(FTrayData));
end;

procedure TFrmConfereArquivoAgentMain.ShowTrayBalloon(const ATitle,
  AText: string);
begin
  if FTrayData.Wnd = 0 then
    Exit;
  FTrayData.uFlags := NIF_INFO;
  StrPLCopy(FTrayData.szInfoTitle, ATitle, Length(FTrayData.szInfoTitle) - 1);
  StrPLCopy(FTrayData.szInfo, AText, Length(FTrayData.szInfo) - 1);
  FTrayData.dwInfoFlags := NIIF_INFO;
  Shell_NotifyIcon(NIM_MODIFY, @FTrayData);
  FTrayData.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
end;

procedure TFrmConfereArquivoAgentMain.HideToTray(const AMessage: string);
begin
  Hide;
  if AMessage <> '' then
    ShowTrayBalloon('Confere Arquivo', AMessage);
end;

procedure TFrmConfereArquivoAgentMain.ShowFromTray;
begin
  Show;
  WindowState := wsNormal;
  Application.Restore;
  SetForegroundWindow(Handle);
end;

procedure TFrmConfereArquivoAgentMain.ScheduleNextSync;
begin
  if tmrAgente.Enabled then
    FNextSyncAt := Now + EncodeTime(0, 0, FConfig.IntervalSeconds, 0)
  else
    FNextSyncAt := 0;
  UpdateTrayMenu;
end;

procedure TFrmConfereArquivoAgentMain.UpdateTrayMenu;
var
  Remaining: Integer;
  TrayTip: string;
begin
  if tmrAgente.Enabled then
  begin
    miStatus.Caption := 'Agente automatico: ATIVO';
    Remaining := SecondsBetween(FNextSyncAt, Now);
    if Remaining < 0 then
      Remaining := 0;
    miProximaSync.Caption := Format('Proxima sincronizacao em %d s', [Remaining]);
    TrayTip := Format('Confere Arquivo | proxima sync em %d s', [Remaining]);
  end
  else
  begin
    miStatus.Caption := 'Agente automatico: PARADO';
    miProximaSync.Caption := 'Proxima sincronizacao: manual';
    TrayTip := 'Confere Arquivo | sincronizacao manual';
  end;

  if FTrayData.Wnd <> 0 then
  begin
    StrPLCopy(FTrayData.szTip, TrayTip, Length(FTrayData.szTip) - 1);
    FTrayData.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
    Shell_NotifyIcon(NIM_MODIFY, @FTrayData);
  end;
end;

procedure TFrmConfereArquivoAgentMain.WMTrayIcon(var Msg: TMessage);
var
  Pt: TPoint;
begin
  case Msg.LParam of
    WM_LBUTTONDBLCLK:
      ShowFromTray;
    WM_RBUTTONUP:
      begin
        SetForegroundWindow(Handle);
        GetCursorPos(Pt);
        TrayPopup.Popup(Pt.X, Pt.Y);
      end;
  end;
end;

procedure TFrmConfereArquivoAgentMain.LoadScreen;
var
  DatabasePath: string;
begin
  mmBancosNFCe.Clear;
  for DatabasePath in FConfig.NFCeDatabasePaths do
    mmBancosNFCe.Lines.Add(DatabasePath);
  mmBancosNFeSaida.Clear;
  for DatabasePath in FConfig.NFeSaidaDatabasePaths do
    mmBancosNFeSaida.Lines.Add(DatabasePath);
  chkAtivarNFCe.Checked := FConfig.EnabledNFCe;
  chkAtivarNFeSaida.Checked := FConfig.EnabledNFeSaida;
  edUsuario.Text := FConfig.FirebirdUser;
  edSenha.Text := FConfig.FirebirdPassword;
  edApiUrl.Text := FConfig.ApiBaseUrl;
  edToken.Text := FConfig.ApiToken;
  edInstalacao.Text := FConfig.InstalacaoID;
  edtIntervalo.Text := FConfig.IntervalSeconds.ToString;
  edtJanela.Text := FConfig.WindowDays.ToString;
  chkAtivo.Checked := FConfig.Enabled;
  chkIniciarWindows.Checked := FConfig.StartWithWindows;
  edEmpresa.Text := '';
  edPendentes.Text := '0';
  edUltimaMensagem.Text := '';
  edUltimaLeitura.Text := '';
  mmEventos.Lines.Text := ReadLastOperationalLines;
end;

procedure TFrmConfereArquivoAgentMain.SaveScreenToConfig;
begin
  FConfig.NFCeDatabasePaths := ParseMemoPaths(mmBancosNFCe);
  FConfig.NFeSaidaDatabasePaths := ParseMemoPaths(mmBancosNFeSaida);
  FConfig.EnabledNFCe := chkAtivarNFCe.Checked;
  FConfig.EnabledNFeSaida := chkAtivarNFeSaida.Checked;
  if Length(FConfig.NFCeDatabasePaths) > 0 then
    FConfig.NFCeDatabasePath := FConfig.NFCeDatabasePaths[0]
  else
    FConfig.NFCeDatabasePath := '';
  if Length(FConfig.NFeSaidaDatabasePaths) > 0 then
    FConfig.NFeSaidaDatabasePath := FConfig.NFeSaidaDatabasePaths[0]
  else
    FConfig.NFeSaidaDatabasePath := '';
  FConfig.SourceDatabasePaths := FConfig.NFCeDatabasePaths;
  FConfig.SourceDatabasePath := FConfig.NFCeDatabasePath;
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
  FConfig.FirstRunPending := False;
  FConfig.StartWithWindows := chkIniciarWindows.Checked;
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
    ScheduleNextSync;
  except
    on E: Exception do
    begin
      AppendEvent('Falha na coleta: ' + E.Message);
      edUltimaMensagem.Text := E.Message;
    end;
  end;
  FBusy := False;
end;

procedure TFrmConfereArquivoAgentMain.StartAutomaticSync;
begin
  tmrAgente.Interval := FConfig.IntervalSeconds * 1000;
  tmrAgente.Enabled := True;
  FConfig.Enabled := True;
  FConfig.FirstRunPending := False;
  chkAtivo.Checked := True;
  SaveAgentConfig(FConfig);
  ScheduleNextSync;
end;

function TFrmConfereArquivoAgentMain.ParseMemoPaths(AMemo: TMemo): TStringDynArray;
var
  I: Integer;
  Value: string;
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.CaseSensitive := False;
    L.Duplicates := dupIgnore;
    for I := 0 to AMemo.Lines.Count - 1 do
    begin
      Value := Trim(AMemo.Lines[I]);
      if Value = '' then
        Continue;
      Value := ExpandFileName(Value);
      if L.IndexOf(Value) < 0 then
        L.Add(Value);
    end;
    SetLength(Result, L.Count);
    for I := 0 to L.Count - 1 do
      Result[I] := L[I];
  finally
    L.Free;
  end;
end;

procedure TFrmConfereArquivoAgentMain.btnSalvarClick(Sender: TObject);
begin
  SaveScreenToConfig;
  RecreateEngine;
  if FConfig.Enabled then
    StartAutomaticSync
  else
  begin
    tmrAgente.Enabled := False;
    ScheduleNextSync;
  end;
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

procedure TFrmConfereArquivoAgentMain.btnSyncTotalClick(Sender: TObject);
begin
  SaveScreenToConfig;
  RecreateEngine;
  try
    FEngine.SyncTotal;
    StartAutomaticSync;
    AppendEvent(FEngine.LastMessage);
    RefreshMonitor;
  except
    on E: Exception do
      AppendEvent('Falha no sync total: ' + E.Message);
  end;
end;

procedure TFrmConfereArquivoAgentMain.btnPararClick(Sender: TObject);
begin
  tmrAgente.Enabled := False;
  FConfig.Enabled := False;
  chkAtivo.Checked := False;
  SaveAgentConfig(FConfig);
  ScheduleNextSync;
  AppendEvent('Agente automatico parado.');
end;

procedure TFrmConfereArquivoAgentMain.btnAbrirLogsClick(Sender: TObject);
begin
  ShellExecute(Handle, 'open', PChar(FConfig.LogPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TFrmConfereArquivoAgentMain.tmrAgenteTimer(Sender: TObject);
begin
  RunPoll;
end;

procedure TFrmConfereArquivoAgentMain.tmrTrayCountdownTimer(Sender: TObject);
begin
  UpdateTrayMenu;
end;

procedure TFrmConfereArquivoAgentMain.miAbrirClick(Sender: TObject);
begin
  ShowFromTray;
end;

procedure TFrmConfereArquivoAgentMain.miSairClick(Sender: TObject);
begin
  FForceExit := True;
  tmrAgente.Enabled := False;
  ScheduleNextSync;
  Close;
end;

end.
