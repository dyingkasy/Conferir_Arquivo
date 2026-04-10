unit Frm_ConfereArquivoOfficeMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
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
    lblDias: TLabel;
    cbStatus: TComboBox;
    edDataInicial: TEdit;
    edDataFinal: TEdit;
    edDias: TEdit;
    btnConsultar: TButton;
    gbResumo: TGroupBox;
    lblTotal: TLabel;
    lblTransmitidas: TLabel;
    lblContingencia: TLabel;
    lblSemFiscal: TLabel;
    lblRejeitadas: TLabel;
    lblCanceladas: TLabel;
    lblValorTotal: TLabel;
    lblValorTransmitido: TLabel;
    lblValorCont: TLabel;
    lblValorSemFiscal: TLabel;
    edTotal: TEdit;
    edTransmitidas: TEdit;
    edContingencia: TEdit;
    edSemFiscal: TEdit;
    edRejeitadas: TEdit;
    edCanceladas: TEdit;
    edValorTotal: TEdit;
    edValorTransmitido: TEdit;
    edValorCont: TEdit;
    edValorSemFiscal: TEdit;
    sgNotas: TStringGrid;
    mmLog: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnHealthClick(Sender: TObject);
    procedure btnConsultarClick(Sender: TObject);
    procedure btnEmpresasClick(Sender: TObject);
    procedure edEmpresaFiltroChange(Sender: TObject);
    procedure lbEmpresasClick(Sender: TObject);
  private
    FConfig: TConfereOfficeConfig;
    FEmpresas: TArray<TConfereEmpresaDisponivel>;
    FVisibleEmpresas: TArray<Integer>;
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
  ApplyGridHeader;
  try
    LoadEmpresas;
  except
    on E: Exception do
      Log('Falha carregando empresas: ' + E.Message);
  end;
end;

procedure TFrmConfereArquivoOfficeMain.LoadScreen;
begin
  edApi.Text := FConfig.ApiBaseUrl;
  edToken.Text := FConfig.ApiToken;
  edDias.Text := FConfig.DiasResumo.ToString;
  cbStatus.Items.Text := 'TODOS'#13#10'TRANSMITIDA'#13#10'CONTINGENCIA'#13#10'SEM_FISCAL'#13#10'AUTORIZADA'#13#10'CONTINGENCIA_AUTORIZADA'#13#10'CONTINGENCIA_PENDENTE'#13#10'PENDENTE_TRANSMISSAO'#13#10'REJEITADA'#13#10'CANCELADA';
  cbStatus.ItemIndex := 0;
  edDataInicial.Text := FormatDateTime('yyyy-mm-dd', Date - 7);
  edDataFinal.Text := FormatDateTime('yyyy-mm-dd', Date);
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
  FConfig.DiasResumo := StrToIntDef(edDias.Text, 7);
  if FConfig.DiasResumo <= 0 then
    FConfig.DiasResumo := 7;
  SaveOfficeConfig(FConfig);
end;

procedure TFrmConfereArquivoOfficeMain.ApplyGridHeader;
begin
  sgNotas.FixedRows := 1;
  sgNotas.ColCount := 10;
  sgNotas.RowCount := 2;
  sgNotas.Cells[0,0] := 'Data';
  sgNotas.Cells[1,0] := 'Hora';
  sgNotas.Cells[2,0] := 'Numero';
  sgNotas.Cells[3,0] := 'Serie';
  sgNotas.Cells[4,0] := 'Status';
  sgNotas.Cells[5,0] := 'Valor';
  sgNotas.Cells[6,0] := 'Cliente';
  sgNotas.Cells[7,0] := 'Documento';
  sgNotas.Cells[8,0] := 'Protocolo';
  sgNotas.Cells[9,0] := 'Chave';
  sgNotas.ColWidths[0] := 76;
  sgNotas.ColWidths[1] := 58;
  sgNotas.ColWidths[2] := 74;
  sgNotas.ColWidths[3] := 46;
  sgNotas.ColWidths[4] := 132;
  sgNotas.ColWidths[5] := 88;
  sgNotas.ColWidths[6] := 210;
  sgNotas.ColWidths[7] := 110;
  sgNotas.ColWidths[8] := 150;
  sgNotas.ColWidths[9] := 260;
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
    Resumo := Client.LoadResumo(FConfig.CNPJEmpresa, StrToIntDef(edDias.Text, 7));
    edTotal.Text := IntToStr(Resumo.QuantidadeTotal);
    edTransmitidas.Text := IntToStr(Resumo.QuantidadeTransmitida);
    edContingencia.Text := IntToStr(Resumo.QuantidadeContingencia);
    edSemFiscal.Text := IntToStr(Resumo.QuantidadeSemFiscal);
    edRejeitadas.Text := IntToStr(Resumo.QuantidadeRejeitada);
    edCanceladas.Text := IntToStr(Resumo.QuantidadeCancelada);
    edValorTotal.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalDocumento);
    edValorTransmitido.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalTransmitido);
    edValorCont.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalContingencia);
    edValorSemFiscal.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalSemFiscal);
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
    Items := Client.LoadLista(FConfig.CNPJEmpresa, StatusValue, Trim(edDataInicial.Text), Trim(edDataFinal.Text), 250);
    sgNotas.RowCount := Max(Length(Items) + 1, 2);
    for I := 0 to Length(Items) - 1 do
    begin
      sgNotas.Cells[0, I + 1] := Items[I].DataVenda;
      sgNotas.Cells[1, I + 1] := Items[I].HoraVenda;
      sgNotas.Cells[2, I + 1] := Items[I].NumeroNFCe;
      sgNotas.Cells[3, I + 1] := Items[I].SerieNFCe;
      sgNotas.Cells[4, I + 1] := Items[I].StatusOperacional;
      sgNotas.Cells[5, I + 1] := FormatFloat('0.00', Items[I].ValorDocumento);
      sgNotas.Cells[6, I + 1] := Items[I].NomeCliente;
      sgNotas.Cells[7, I + 1] := Items[I].DocumentoCliente;
      sgNotas.Cells[8, I + 1] := Items[I].Protocolo;
      sgNotas.Cells[9, I + 1] := Items[I].ChaveAcesso;
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

end.
