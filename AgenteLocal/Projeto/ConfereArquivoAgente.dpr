program ConfereArquivoAgente;

uses
  System.SysUtils,
  Vcl.Forms,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.IB,
  FireDAC.Phys.SQLite,
  FireDAC.DApt,
  FireDAC.VCLUI.Wait,
  Frm_ConfereArquivoAgentMain in 'Frm_ConfereArquivoAgentMain.pas' {FrmConfereArquivoAgentMain},
  ConfereArquivo.Agent.Config in 'ConfereArquivo.Agent.Config.pas',
  ConfereArquivo.Agent.Source in 'ConfereArquivo.Agent.Source.pas',
  ConfereArquivo.Agent.SourceNFeSaida in 'ConfereArquivo.Agent.SourceNFeSaida.pas',
  ConfereArquivo.Agent.Queue in 'ConfereArquivo.Agent.Queue.pas',
  ConfereArquivo.Agent.Sync in 'ConfereArquivo.Agent.Sync.pas',
  ConfereArquivo.Types in '..\..\Common\ConfereArquivo.Types.pas',
  ConfereArquivo.Json in '..\..\Common\ConfereArquivo.Json.pas',
  ConfereArquivo.Logger in '..\..\Common\ConfereArquivo.Logger.pas';

{$R 'AgentIcon.res'}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmConfereArquivoAgentMain, FrmConfereArquivoAgentMain);
  Application.Run;
end.
