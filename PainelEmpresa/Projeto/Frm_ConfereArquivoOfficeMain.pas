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
    gbConexao: TGroupBox;
    lblApi: TLabel;
    lblToken: TLabel;
    lblCNPJ: TLabel;
    edApi: TEdit;
    edToken: TEdit;
    edCNPJ: TEdit;
    btnSalvar: TButton;
    btnHealth: TButton;
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
    lblAutorizadas: TLabel;
    lblContingencia: TLabel;
    lblPendentes: TLabel;
    lblRejeitadas: TLabel;
    lblCanceladas: TLabel;
    lblValorTotal: TLabel;
    lblValorCont: TLabel;
    lblValorPend: TLabel;
    edTotal: TEdit;
    edAutorizadas: TEdit;
    edContingencia: TEdit;
    edPendentes: TEdit;
    edRejeitadas: TEdit;
    edCanceladas: TEdit;
    edValorTotal: TEdit;
    edValorCont: TEdit;
    edValorPend: TEdit;
    sgNotas: TStringGrid;
    mmLog: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnHealthClick(Sender: TObject);
    procedure btnConsultarClick(Sender: TObject);
  private
    FConfig: TConfereOfficeConfig;
    procedure LoadScreen;
    procedure SaveScreen;
    procedure ApplyGridHeader;
    procedure Log(const AText: string);
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
end;

procedure TFrmConfereArquivoOfficeMain.LoadScreen;
begin
  edApi.Text := FConfig.ApiBaseUrl;
  edToken.Text := FConfig.ApiToken;
  edCNPJ.Text := FConfig.CNPJEmpresa;
  edDias.Text := FConfig.DiasResumo.ToString;
  cbStatus.Items.Text := 'TODOS'#13#10'AUTORIZADA'#13#10'CONTINGENCIA'#13#10'CONTINGENCIA_AUTORIZADA'#13#10'CONTINGENCIA_PENDENTE'#13#10'PENDENTE_TRANSMISSAO'#13#10'REJEITADA'#13#10'CANCELADA';
  cbStatus.ItemIndex := 0;
  edDataInicial.Text := FormatDateTime('yyyy-mm-dd', Date - 7);
  edDataFinal.Text := FormatDateTime('yyyy-mm-dd', Date);
end;

procedure TFrmConfereArquivoOfficeMain.SaveScreen;
begin
  FConfig.ApiBaseUrl := Trim(edApi.Text);
  FConfig.ApiToken := Trim(edToken.Text);
  FConfig.CNPJEmpresa := Trim(edCNPJ.Text);
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
  sgNotas.ColWidths[0] := 80;
  sgNotas.ColWidths[1] := 70;
  sgNotas.ColWidths[2] := 80;
  sgNotas.ColWidths[3] := 60;
  sgNotas.ColWidths[4] := 150;
  sgNotas.ColWidths[5] := 90;
  sgNotas.ColWidths[6] := 220;
  sgNotas.ColWidths[7] := 120;
  sgNotas.ColWidths[8] := 190;
  sgNotas.ColWidths[9] := 320;
end;

procedure TFrmConfereArquivoOfficeMain.Log(const AText: string);
begin
  mmLog.Lines.Add(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + '  ' + AText);
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
    edAutorizadas.Text := IntToStr(Resumo.QuantidadeAutorizada);
    edContingencia.Text := IntToStr(Resumo.QuantidadeContingencia);
    edPendentes.Text := IntToStr(Resumo.QuantidadePendente);
    edRejeitadas.Text := IntToStr(Resumo.QuantidadeRejeitada);
    edCanceladas.Text := IntToStr(Resumo.QuantidadeCancelada);
    edValorTotal.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalDocumento);
    edValorCont.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalContingencia);
    edValorPend.Text := FormatFloat('R$ ,0.00', Resumo.ValorTotalPendente);
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
  LoadResumo;
  LoadLista;
  Log('Consulta executada com sucesso.');
end;

end.
