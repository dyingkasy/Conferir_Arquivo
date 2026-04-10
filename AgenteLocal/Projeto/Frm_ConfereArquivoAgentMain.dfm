object FrmConfereArquivoAgentMain: TFrmConfereArquivoAgentMain
  Left = 0
  Top = 0
  Caption = 'Confere Arquivo - Agente Local'
  ClientHeight = 720
  ClientWidth = 1080
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 17
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1080
    Height = 88
    Align = alTop
    BevelOuter = bvNone
    Color = 3815994
    ParentBackground = False
    TabOrder = 0
    object lblTitulo: TLabel
      Left = 20
      Top = 18
      Width = 265
      Height = 30
      Caption = 'Confere Arquivo - Coletor'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -24
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object lblSubtitulo: TLabel
      Left = 20
      Top = 53
      Width = 444
      Height = 17
      Caption = 'Coleta NFC-e do PAFECF e envia o espelho fiscal para a API da VPS.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15724527
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object gbOrigem: TGroupBox
    Left = 16
    Top = 104
    Width = 521
    Height = 153
    Caption = 'Origem Firebird'
    TabOrder = 1
    object lblBanco: TLabel
      Left = 16
      Top = 33
      Width = 92
      Height = 17
      Caption = 'Banco PAFECF'
    end
    object lblUsuario: TLabel
      Left = 16
      Top = 89
      Width = 48
      Height = 17
      Caption = 'Usuario'
    end
    object lblSenha: TLabel
      Left = 265
      Top = 89
      Width = 37
      Height = 17
      Caption = 'Senha'
    end
    object edBanco: TEdit
      Left = 16
      Top = 52
      Width = 489
      Height = 25
      TabOrder = 0
    end
    object edUsuario: TEdit
      Left = 16
      Top = 108
      Width = 225
      Height = 25
      TabOrder = 1
    end
    object edSenha: TEdit
      Left = 265
      Top = 108
      Width = 240
      Height = 25
      PasswordChar = '*'
      TabOrder = 2
    end
  end
  object gbServidor: TGroupBox
    Left = 553
    Top = 104
    Width = 511
    Height = 153
    Caption = 'Servidor VPS'
    TabOrder = 2
    object lblApiUrl: TLabel
      Left = 16
      Top = 33
      Width = 88
      Height = 17
      Caption = 'Base URL API'
    end
    object lblToken: TLabel
      Left = 16
      Top = 89
      Width = 37
      Height = 17
      Caption = 'Token'
    end
    object lblInstalacao: TLabel
      Left = 265
      Top = 89
      Width = 72
      Height = 17
      Caption = 'Instalacao ID'
    end
    object edApiUrl: TEdit
      Left = 16
      Top = 52
      Width = 479
      Height = 25
      TabOrder = 0
    end
    object edToken: TEdit
      Left = 16
      Top = 108
      Width = 225
      Height = 25
      TabOrder = 1
    end
    object edInstalacao: TEdit
      Left = 265
      Top = 108
      Width = 230
      Height = 25
      TabOrder = 2
    end
  end
  object gbAgente: TGroupBox
    Left = 16
    Top = 273
    Width = 1048
    Height = 121
    Caption = 'Controle do Agente'
    TabOrder = 3
    object lblIntervalo: TLabel
      Left = 16
      Top = 34
      Width = 108
      Height = 17
      Caption = 'Intervalo segundos'
    end
    object lblJanela: TLabel
      Left = 154
      Top = 34
      Width = 111
      Height = 17
      Caption = 'Janela dias revisao'
    end
    object edtIntervalo: TEdit
      Left = 16
      Top = 57
      Width = 105
      Height = 25
      TabOrder = 0
    end
    object edtJanela: TEdit
      Left = 154
      Top = 57
      Width = 111
      Height = 25
      TabOrder = 1
    end
    object chkAtivo: TCheckBox
      Left = 294
      Top = 60
      Width = 109
      Height = 17
      Caption = 'Agente ativo'
      TabOrder = 2
    end
    object btnSalvar: TButton
      Left = 437
      Top = 53
      Width = 105
      Height = 31
      Caption = 'Salvar'
      TabOrder = 3
      OnClick = btnSalvarClick
    end
    object btnValidarBanco: TButton
      Left = 554
      Top = 53
      Width = 118
      Height = 31
      Caption = 'Validar Banco'
      TabOrder = 4
      OnClick = btnValidarBancoClick
    end
    object btnValidarApi: TButton
      Left = 684
      Top = 53
      Width = 113
      Height = 31
      Caption = 'Validar API'
      TabOrder = 5
      OnClick = btnValidarApiClick
    end
    object btnColetarAgora: TButton
      Left = 809
      Top = 53
      Width = 104
      Height = 31
      Caption = 'Coletar Agora'
      TabOrder = 6
      OnClick = btnColetarAgoraClick
    end
    object btnSyncTotal: TButton
      Left = 809
      Top = 86
      Width = 104
      Height = 27
      Caption = 'Sync Total'
      TabOrder = 11
      OnClick = btnSyncTotalClick
    end
    object btnIniciar: TButton
      Left = 925
      Top = 22
      Width = 104
      Height = 28
      Caption = 'Iniciar'
      TabOrder = 7
      OnClick = btnIniciarClick
    end
    object btnParar: TButton
      Left = 925
      Top = 56
      Width = 104
      Height = 28
      Caption = 'Parar'
      TabOrder = 8
      OnClick = btnPararClick
    end
    object btnAbrirLogs: TButton
      Left = 554
      Top = 86
      Width = 118
      Height = 27
      Caption = 'Abrir Logs'
      TabOrder = 9
      OnClick = btnAbrirLogsClick
    end
    object btnTestarTudo: TButton
      Left = 684
      Top = 86
      Width = 113
      Height = 27
      Caption = 'Testar Tudo'
      TabOrder = 10
      OnClick = btnTestarTudoClick
    end
  end
  object gbMonitor: TGroupBox
    Left = 16
    Top = 410
    Width = 1048
    Height = 294
    Caption = 'Monitor de Operacao'
    TabOrder = 4
    object lblEmpresa: TLabel
      Left = 16
      Top = 34
      Width = 96
      Height = 17
      Caption = 'Empresa/CNPJ'
    end
    object lblPendentes: TLabel
      Left = 560
      Top = 34
      Width = 61
      Height = 17
      Caption = 'Pendentes'
    end
    object lblUltimaMsg: TLabel
      Left = 16
      Top = 84
      Width = 102
      Height = 17
      Caption = 'Ultima mensagem'
    end
    object lblUltimaLeitura: TLabel
      Left = 846
      Top = 34
      Width = 88
      Height = 17
      Caption = 'Ultima leitura'
    end
    object edEmpresa: TEdit
      Left = 16
      Top = 53
      Width = 521
      Height = 25
      ReadOnly = True
      TabOrder = 0
    end
    object edPendentes: TEdit
      Left = 560
      Top = 53
      Width = 129
      Height = 25
      ReadOnly = True
      TabOrder = 1
    end
    object edUltimaMensagem: TEdit
      Left = 16
      Top = 103
      Width = 1013
      Height = 25
      ReadOnly = True
      TabOrder = 2
    end
    object edUltimaLeitura: TEdit
      Left = 846
      Top = 53
      Width = 183
      Height = 25
      ReadOnly = True
      TabOrder = 3
    end
    object mmEventos: TMemo
      Left = 16
      Top = 144
      Width = 1013
      Height = 129
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 4
    end
  end
  object tmrAgente: TTimer
    Enabled = False
    Interval = 15000
    OnTimer = tmrAgenteTimer
    Left = 1000
    Top = 16
  end
end
