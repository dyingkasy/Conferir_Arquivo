program ConfereArquivoOffice;

uses
  System.SysUtils,
  Vcl.Forms,
  Frm_ConfereArquivoOfficeMain in 'Frm_ConfereArquivoOfficeMain.pas' {FrmConfereArquivoOfficeMain},
  ConfereArquivo.Office.Config in 'ConfereArquivo.Office.Config.pas',
  ConfereArquivo.Office.Client in 'ConfereArquivo.Office.Client.pas',
  ConfereArquivo.Logger in '..\..\Common\ConfereArquivo.Logger.pas';

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmConfereArquivoOfficeMain, FrmConfereArquivoOfficeMain);
  Application.Run;
end.
