unit Frm_ConfereArquivoOfficeMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math, System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids, ConfereArquivo.Office.Config, ConfereArquivo.Office.Client;

type
  TFrmConfereArquivoOfficeMain = class(TForm)
    pnlHeader: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    pnlLeft: TPanel;
    gbConexao: TGroupBox;
    lblApi: TLabel;
    lblToken: TLabel;
    edApi: TEdit;
    edToken: TEdit;
    btnSalvar: TButton;
    btnHealth: TButton;
    btnEmpresas: TButton;
    gbEmpresas: TGroupBox;
    lblEmpresaFiltro: TLabel;
    edEmpresaFiltro: TEdit;
    lbEmpresas: TListBox;
    lblQtdEmpresas: TLabel;
    pnlConteudo: TPanel;
    gbFiltros: TGroupBox;
    lblStatus: TLabel;
    lblDataInicial: TLabel;
    lblDataFinal: TLabel;
    cbStatus: TComboBox;
    dtDataInicial: TDateTimePicker;
    dtDataFinal: TDateTimePicker;
    btnConsultar: TButton;
    gbResumo: TGroupBox;
    gbTributos: TGroupBox;
    lblTotal: TLabel;
    lblTransmitidas: TLabel;
    lblContingencia: TLabel;
    lblSemFiscal: TLabel;
    lblErro: TLabel;
    lblValorTotal: TLabel;
    lblValorTransmitido: TLabel;
    lblValorCont: TLabel;
    lblValorSemFiscal: TLabel;
    lblTribBase: TLabel;
    lblTribICMS: TLabel;
    lblTribPIS: TLabel;
    lblTribCOFINS: TLabel;
    lblTribFederal: TLabel;
    lblTribEstadual: TLabel;
    edTotal: TEdit;
    edTransmitidas: TEdit;
    edContingencia: TEdit;
    edSemFiscal: TEdit;
    edErro: TEdit;
    edValorTotal: TEdit;
    edValorTransmitido: TEdit;
    edValorCont: TEdit;
    edValorSemFiscal: TEdit;
    edValorErro: TEdit;
    lblValorErro: TLabel;
    edTribBase: TEdit;
    edTribICMS: TEdit;
    edTribPIS: TEdit;
    edTribCOFINS: TEdit;
    edTribFederal: TEdit;
    edTribEstadual: TEdit;
    sgNotas: TStringGrid;
    mmLog: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnHealthClick(Sender: TObject);
    procedure btnConsultarClick(Sender: TObject);
    procedure btnEmpresasClick(Sender: TObject);
    procedure edEmpresaFiltroChange(Sender: TObject);
    procedure lbEmpresasClick(Sender: TObject);
    procedure sgNotasDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
  private
    FConfig: TConfereOfficeConfig;
    FEmpresas: TArray<TConfereEmpresaDisponivel>;
    FVisibleEmpresas: TArray<Integer>;
    function FriendlyStatus(const AGrupo, AStatus: string): string;
    procedure ApplyVisualStyle;
    procedure StyleReadOnlyEdit(AEdit: TEdit; const AColor: TColor);
    procedure StyleButton(AButton: TButton; const AColor: TColor; AFontColor: TColor = clWhite);
    procedure LoadScreen;
    procedure SaveScreen;
    procedure ApplyGridHeader;
    procedure Log(const AText: string);
    procedure LoadEmpresas;
    procedure ApplyCompanyFilter;
    function GetSelectedEmpresaIndex: Integer;
    procedure LoadResumo;
    procedure LoadLista;
  public
  end;

var
  FrmConfereArquivoOfficeMain: TFrmConfereArquivoOfficeMain;

implementation

{$R *.dfm}

uses
  ConfereArquivo.Logger;

procedure TFrmConfereArquivoOfficeMain.FormCreate(Sender: TObject);
begin
  LoadOfficeConfig(FConfig);
  ConfigureConfereLogger(FConfig.LogPath);
  LoadScreen;
  ApplyVisualStyle;
  ApplyGridHeader;
  try
    LoadEmpresas;
  except
    on E: Exception do
      Log('Falha carregando empresas: ' + E.Message);
  end;
end;

procedure TFrmConfereArquivoOfficeMain.StyleReadOnlyEdit(AEdit: TEdit; const AColor: TColor);
begin
  AEdit.Color := AColor;
  AEdit.Font.Color := $00342E25;
  AEdit.Font.Style := [fsBold];
  AEdit.ReadOnly := True;
  AEdit.ParentColor := False;
end;

procedure TFrmConfereArquivoOfficeMain.StyleButton(AButton: TButton; const AColor: TColor; AFontColor: TColor);
begin
  AButton.Tag := AColor;
  AButton.Font.Color := AFontColor;
  AButton.Font.Style := [fsBold];
end;

procedure TFrmConfereArquivoOfficeMain.ApplyVisualStyle;
var
  I: Integer;
begin
  Color := $00F4F6F8;
  pnlLeft.Color := $00F0F3F7;
  pnlLeft.ParentBackground := False;
  pnlConteudo.Color := $00F8FAFC;
  pnlConteudo.ParentBackground := False;

  gbConexao.Font.Style := [fsBold];
  gbEmpresas.Font.Style := [fsBold];
  gbFiltros.Font.Style := [fsBold];
  gbResumo.Font.Style := [fsBold];
  gbTributos.Font.Style := [fsBold];

  StyleButton(btnSalvar, $003A6EA5);
  StyleButton(btnHealth, $004A8A4A);
  StyleButton(btnEmpresas, $006A7680);
  StyleButton(btnConsultar, $003A6EA5);

  for I := 0 to ComponentCount - 1 do
    if Components[I] is TEdit then
      (Components[I] as TEdit).Font.Name := 'Segoe UI';

  StyleReadOnlyEdit(edTotal, $00F2F4F7);
  StyleReadOnlyEdit(edTransmitidas, $00E6F5E8);
  StyleReadOnlyEdit(edContingencia, $00FFF0D9);
  StyleReadOnlyEdit(edSemFiscal, $00FBE7D8);
  StyleReadOnlyEdit(edErro, $00FCE4E4);
  StyleReadOnlyEdit(edValorTotal, $00F2F4F7);
  StyleReadOnlyEdit(edValorTransmitido, $00E6F5E8);
  StyleReadOnlyEdit(edValorCont, $00FFF0D9);
  StyleReadOnlyEdit(edValorSemFiscal, $00FBE7D8);
  StyleReadOnlyEdit(edValorErro, $00FCE4E4);

  StyleReadOnlyEdit(edTribBase, $00EAF0F7);
  StyleReadOnlyEdit(edTribICMS, $00EAF0F7);
  StyleReadOnlyEdit(edTribPIS, $00EAF0F7);
  StyleReadOnlyEdit(edTribCOFINS, $00EAF0F7);
  StyleReadOnlyEdit(edTribFederal, $00EAF0F7);
  StyleReadOnlyEdit(edTribEstadual, $00EAF0F7);

  lbEmpresas.Color := clWhite;
  lbEmpresas.Font.Name := 'Segoe UI';
  lbEmpresas.Font.Height := -12;
  mmLog.Color := clWhite;
  mmLog.Font.Name := 'Consolas';
  mmLog.Font.Height := -11;
  sgNotas.Font.Name := 'Segoe UI';
  sgNotas.Font.Height := -12;
end;

procedure TFrmConfereArquivoOfficeMain.LoadScreen;
begin
  edApi.Text := FConfig.ApiBaseUrl;
  edToken.Text := FConfig.ApiToken;
  cbStatus.Items.Text := 'TODOS'#13#10'TRANSMITIDA'#13#10'CONTINGENCIA'#13#10'ERRO'#13#10'SEM_FISCAL';
  cbStatus.ItemIndex := 0;
  dtDataInicial.Date := StartOfTheMonth(Date);
  dtDataFinal.Date := Date;
  edEmpresaFiltro.Text := '';
end;

procedure TFrmConfereArquivoOfficeMain.SaveScreen;
var
  EmpresaIdx: Integer;
begin
  FConfig.ApiBaseUrl := Trim(edApi.Text);
  FConfig.ApiToken := Trim(edToken.Text);
  EmpresaIdx := GetSelectedEmpresaIndex;
  if (EmpresaIdx >= 0) and (EmpresaIdx < Length(FEmpresas)) then
    FConfig.CNPJEmpresa := FEmpresas[EmpresaIdx].CNPJ;
  SaveOfficeConfig(FConfig);
end;

procedure TFrmConfereArquivoOfficeMain.ApplyGridHeader;
begin
  sgNotas.FixedRows := 1;
  sgNotas.ColCount := 14;
  sgNotas.RowCount := 2;
  sgNotas.Cells[0,0] := 'Data';
  sgNotas.Cells[1,0] := 'Hora';
  sgNotas.Cells[2,0] := 'Grupo';
  sgNotas.Cells[3,0] := 'Status Final';
  sgNotas.Cells[4,0] := 'Transm.';
  sgNotas.Cells[5,0] := 'Numero';
  sgNotas.Cells[6,0] := 'Serie';
  sgNotas.Cells[7,0] := 'Valor';
  sgNotas.Cells[8,0] := 'ICMS';
  sgNotas.Cells[9,0] := 'PIS';
  sgNotas.Cells[10,0] := 'COFINS';
  sgNotas.Cells[11,0] := 'Cliente';
  sgNotas.Cells[12,0] := 'Documento';
  sgNotas.Cells[13,0] := 'Protocolo';
  sgNotas.ColWidths[0] := 72;
  sgNotas.ColWidths[1] := 58;
  sgNotas.ColWidths[2] := 92;
  sgNotas.ColWidths[3] := 130;
  sgNotas.ColWidths[4] := 72;
  sgNotas.ColWidths[5] := 70;
  sgNotas.ColWidths[6] := 42;
  sgNotas.ColWidths[7] := 76;
  sgNotas.ColWidths[8] := 66;
  sgNotas.ColWidths[9] := 60;
  sgNotas.ColWidths[10] := 68;
  sgNotas.ColWidths[11] := 210;
  sgNotas.ColWidths[12] := 108;
  sgNotas.ColWidths[13] := 148;
end;

function TFrmConfereArquivoOfficeMain.FriendlyStatus(const AGrupo,
  AStatus: string): string;
var
  Grupo, Status: string;
begin
  Grupo := UpperCase(Trim(AGrupo));
  Status := UpperCase(Trim(AStatus));

  if Grupo = 'TRANSMITIDA' then
    Exit('AUTORIZADA');
  if Grupo = 'CONTINGENCIA' then
    Exit('CONTINGENCIA');
  if Grupo = 'SEM_FISCAL' then
    Exit('SEM FISCAL');
  if Grupo = 'ERRO' then
    Exit('ERRO');

  if Status = 'CONTINGENCIA_AUTORIZADA' then
    Exit('AUTORIZADA');
  if Status = 'CONTINGENCIA_PENDENTE' then
    Exit('CONTINGENCIA');
  if Status = 'PENDENTE_TRANSMISSAO' then
    Exit('SEM FISCAL');
  if (Status = 'REJEITADA') or (Status = 'CANCELADA') then
    Exit('ERRO');

  Result := Trim(AStatus);
end;

procedure TFrmConfereArquivoOfficeMain.Log(const AText: string);
begin
  mmLog.Lines.Add(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + '  ' + AText);
end;

procedure TFrmConfereArquivoOfficeMain.LoadEmpresas;
var
  Client: TConfereOfficeClient;
begin
  Client := TConfereOfficeClient.Create(FConfig.ApiBaseUrl, FConfig.ApiToken);
  try
    FEmpresas := Client.LoadEmpresas;
    ApplyCompanyFilter;
    Log(Format('Empresas carregadas: %d', [Length(FEmpresas)]));
  finally
    Client.Free;
  end;
end;

procedure TFrmConfereArquivoOfficeMain.ApplyCompanyFilter;
var
  I, VisibleCount, SelectListIdx: Integer;
  FilterText, DisplayText: string;
begin
  FilterText := Trim(LowerCase(edEmpresaFiltro.Text));
  SetLength(FVisibleEmpresas, 0);
  lbEmpresas.Items.BeginUpdate;
  try
    lbEmpresas.Items.Clear;
    SelectListIdx := -1;
    VisibleCount := 0;
    for I := 0 to Length(FEmpresas) - 1 do
    begin
      DisplayText := Format('%s  |  %s  |  %d XML', [FEmpresas[I].CNPJ, FEmpresas[I].RazaoSocial, FEmpresas[I].QuantidadeXML]);
      if (FilterText <> '') and
         (Pos(FilterText, LowerCase(FEmpresas[I].CNPJ)) = 0) and
         (Pos(FilterText, LowerCase(FEmpresas[I].RazaoSocial)) = 0) then
        Continue;
      SetLength(FVisibleEmpresas, VisibleCount + 1);
      FVisibleEmpresas[VisibleCount] := I;
      lbEmpresas.Items.Add(DisplayText);
      if SameText(FEmpresas[I].CNPJ, FConfig.CNPJEmpresa) then
        SelectListIdx := VisibleCount;
      Inc(VisibleCount);
    end;
    if (SelectListIdx < 0) and (lbEmpresas.Items.Count > 0) then
      SelectListIdx := 0;
    lbEmpresas.ItemIndex := SelectListIdx;
    if SelectListIdx >= 0 then
      FConfig.CNPJEmpresa := FEmpresas[FVisibleEmpresas[SelectListIdx]].CNPJ;
    lblQtdEmpresas.Caption := Format('Empresas na lista: %d', [lbEmpresas.Items.Count]);
  finally
    lbEmpresas.Items.EndUpdate;
  end;
end;

function TFrmConfereArquivoOfficeMain.GetSelectedEmpresaIndex: Integer;
begin
  Result := -1;
  if (lbEmpresas.ItemIndex >= 0) and (lbEmpresas.ItemIndex < Length(FVisibleEmpresas)) then
    Result := FVisibleEmpresas[lbEmpresas.ItemIndex];
end;

procedure TFrmConfereArquivoOfficeMain.LoadResumo;
var
  Client: TConfereOfficeClient;
  Resumo: TConfereResumo;
begin
  Client := TConfereOfficeClient.Create(FConfig.ApiBaseUrl, FConfig.ApiToken);
  try
    Resumo := Client.LoadResumo(
      FConfig.CNPJEmpresa,
      FormatDateTime('yyyy-mm-dd', dtDataInicial.Date),
      FormatDateTime('yyyy-mm-dd', dtDataFinal.Date),
      FConfig.DiasResumo);
    edTotal.Text := IntToStr(Resumo.QuantidadeTotal);
    edTransmitidas.Text := IntToStr(Resumo.QuantidadeTransmitida);
    edContingencia.Text := IntToStr(Resumo.QuantidadeContingencia);
    edSemFiscal.Text := IntToStr(Resumo.QuantidadeSemFiscal);
    edErro.Text := IntToStr(Resumo.QuantidadeErro);
    edValorTotal.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalDocumento);
    edValorTransmitido.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalTransmitido);
    edValorCont.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalContingencia);
    edValorSemFiscal.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalSemFiscal);
    edValorErro.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalErro);
    edTribBase.Text := FormatFloat('R$ ,0.00', Resumo.ValorBaseICMS);
    edTribICMS.Text := FormatFloat('R$ ,0.00', Resumo.ValorICMS);
    edTribPIS.Text := FormatFloat('R$ ,0.00', Resumo.ValorPIS);
    edTribCOFINS.Text := FormatFloat('R$ ,0.00', Resumo.ValorCOFINS);
    edTribFederal.Text := FormatFloat('R$ ,0.00', Resumo.ValorImpostoFederal);
    edTribEstadual.Text := FormatFloat('R$ ,0.00', Resumo.ValorImpostoEstadual);
  finally
    Client.Free;
  end;
end;

procedure TFrmConfereArquivoOfficeMain.LoadLista;
var
  Client: TConfereOfficeClient;
  Items: TArray<TConfereNotaConsulta>;
  I: Integer;
  StatusValue: string;
begin
  Client := TConfereOfficeClient.Create(FConfig.ApiBaseUrl, FConfig.ApiToken);
  try
    StatusValue := '';
    if cbStatus.ItemIndex > 0 then
      StatusValue := cbStatus.Text;
    Items := Client.LoadLista(
      FConfig.CNPJEmpresa,
      StatusValue,
      FormatDateTime('yyyy-mm-dd', dtDataInicial.Date),
      FormatDateTime('yyyy-mm-dd', dtDataFinal.Date),
      250);
    sgNotas.RowCount := Max(Length(Items) + 1, 2);
    for I := 0 to Length(Items) - 1 do
    begin
      sgNotas.Cells[0, I + 1] := Items[I].DataVenda;
      sgNotas.Cells[1, I + 1] := Items[I].HoraVenda;
      sgNotas.Cells[2, I + 1] := Items[I].GrupoConferencia;
      sgNotas.Cells[3, I + 1] := FriendlyStatus(Items[I].GrupoConferencia, Items[I].StatusOperacional);
      sgNotas.Cells[4, I + 1] := Items[I].DataTransmissao;
      sgNotas.Cells[5, I + 1] := Items[I].NumeroNFCe;
      sgNotas.Cells[6, I + 1] := Items[I].SerieNFCe;
      sgNotas.Cells[7, I + 1] := FormatFloat('0.00', Items[I].ValorDocumento);
      sgNotas.Cells[8, I + 1] := FormatFloat('0.00', Items[I].ICMS);
      sgNotas.Cells[9, I + 1] := FormatFloat('0.00', Items[I].PIS);
      sgNotas.Cells[10, I + 1] := FormatFloat('0.00', Items[I].COFINS);
      sgNotas.Cells[11, I + 1] := Items[I].NomeCliente;
      sgNotas.Cells[12, I + 1] := Items[I].DocumentoCliente;
      sgNotas.Cells[13, I + 1] := Items[I].Protocolo;
    end;
  finally
    Client.Free;
  end;
end;

procedure TFrmConfereArquivoOfficeMain.btnConsultarClick(Sender: TObject);
begin
  SaveScreen;
  if Trim(FConfig.CNPJEmpresa) = '' then
    raise Exception.Create('Selecione uma empresa para consultar.');
  LoadResumo;
  LoadLista;
  Log('Consulta executada com sucesso.');
end;

procedure TFrmConfereArquivoOfficeMain.btnEmpresasClick(Sender: TObject);
begin
  SaveScreen;
  LoadEmpresas;
end;

procedure TFrmConfereArquivoOfficeMain.btnSalvarClick(Sender: TObject);
begin
  SaveScreen;
  Log('Configuracao salva.');
end;

procedure TFrmConfereArquivoOfficeMain.btnHealthClick(Sender: TObject);
var
  Client: TConfereOfficeClient;
begin
  SaveScreen;
  Client := TConfereOfficeClient.Create(FConfig.ApiBaseUrl, FConfig.ApiToken);
  try
    Log('Health: ' + Client.Health);
  finally
    Client.Free;
  end;
  LoadEmpresas;
end;

procedure TFrmConfereArquivoOfficeMain.edEmpresaFiltroChange(Sender: TObject);
begin
  ApplyCompanyFilter;
end;

procedure TFrmConfereArquivoOfficeMain.lbEmpresasClick(Sender: TObject);
var
  EmpresaIdx: Integer;
begin
  EmpresaIdx := GetSelectedEmpresaIndex;
  if EmpresaIdx >= 0 then
  begin
    FConfig.CNPJEmpresa := FEmpresas[EmpresaIdx].CNPJ;
    SaveOfficeConfig(FConfig);
  end;
end;

procedure TFrmConfereArquivoOfficeMain.sgNotasDrawCell(Sender: TObject; ACol,
  ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  FillColor, FontColor: TColor;
  Text: string;
begin
  Grid := Sender as TStringGrid;
  if ARow = 0 then
  begin
    Grid.Canvas.Brush.Color := $00E6E6E6;
    Grid.Canvas.Font.Color := clBlack;
  end
  else
  begin
    Text := UpperCase(Grid.Cells[2, ARow]);
    if Text = 'TRANSMITIDA' then
    begin
      FillColor := $00EAF6EA;
      FontColor := $001F5E2E;
    end
    else if Text = 'CONTINGENCIA' then
    begin
      FillColor := $00EEF4FF;
      FontColor := $00694A00;
    end
    else if Text = 'ERRO' then
    begin
      FillColor := $00FCE4E4;
      FontColor := $007A2020;
    end
    else
    begin
      FillColor := $00F8F1E8;
      FontColor := $007A3E00;
    end;

    if gdSelected in State then
      Grid.Canvas.Brush.Color := $00D9B55D
    else
      Grid.Canvas.Brush.Color := FillColor;

    Grid.Canvas.Font.Color := FontColor;
  end;

  Grid.Canvas.FillRect(Rect);
  Text := Grid.Cells[ACol, ARow];
  InflateRect(Rect, -3, 0);
  DrawText(Grid.Canvas.Handle, PChar(Text), Length(Text), Rect, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
end;

end.
