object FrmConfereArquivoOfficeMain: TFrmConfereArquivoOfficeMain
  Left = 0
  Top = 0
  Caption = 'Confere Arquivo - Painel Empresa'
  ClientHeight = 760
  ClientWidth = 1220
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 17
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1220
    Height = 84
    Align = alTop
    BevelOuter = bvNone
    Color = 3815994
    ParentBackground = False
    TabOrder = 0
    object lblTitulo: TLabel
      Left = 20
      Top = 16
      Width = 288
      Height = 30
      Caption = 'Confere Arquivo - Painel'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -24
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object lblSubtitulo: TLabel
      Left = 20
      Top = 49
      Width = 373
      Height = 17
      Caption = 'Consulta espelho de NFC-e recebido pela API da VPS.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15724527
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object gbConexao: TGroupBox
    Left = 16
    Top = 96
    Width = 1188
    Height = 97
    Caption = 'Conexao'
    TabOrder = 1
    object lblApi: TLabel
      Left = 16
      Top = 30
      Width = 50
      Height = 17
      Caption = 'API URL'
    end
    object lblToken: TLabel
      Left = 462
      Top = 30
      Width = 37
      Height = 17
      Caption = 'Token'
    end
    object lblEmpresaSel: TLabel
      Left = 811
      Top = 30
      Width = 47
      Height = 17
      Caption = 'Empresa'
    end
    object edApi: TEdit
      Left = 16
      Top = 49
      Width = 430
      Height = 25
      TabOrder = 0
    end
    object edToken: TEdit
      Left = 462
      Top = 49
      Width = 463
      Height = 25
      TabOrder = 1
    end
    object cbEmpresa: TComboBox
      Left = 811
      Top = 49
      Width = 253
      Height = 25
      Style = csDropDownList
      TabOrder = 2
    end
    object btnSalvar: TButton
      Left = 1078
      Top = 17
      Width = 95
      Height = 23
      Caption = 'Salvar'
      TabOrder = 3
      OnClick = btnSalvarClick
    end
    object btnHealth: TButton
      Left = 1078
      Top = 44
      Width = 95
      Height = 23
      Caption = 'Health'
      TabOrder = 4
      OnClick = btnHealthClick
    end
    object btnEmpresas: TButton
      Left = 1078
      Top = 69
      Width = 95
      Height = 23
      Caption = 'Empresas'
      TabOrder = 5
      OnClick = btnEmpresasClick
    end
  end
  object gbFiltros: TGroupBox
    Left = 16
    Top = 202
    Width = 1188
    Height = 89
    Caption = 'Filtros'
    TabOrder = 2
    object lblStatus: TLabel
      Left = 16
      Top = 29
      Width = 37
      Height = 17
      Caption = 'Status'
    end
    object lblDataInicial: TLabel
      Left = 235
      Top = 29
      Width = 65
      Height = 17
      Caption = 'Data inicial'
    end
    object lblDataFinal: TLabel
      Left = 373
      Top = 29
      Width = 56
      Height = 17
      Caption = 'Data final'
    end
    object lblDias: TLabel
      Left = 511
      Top = 29
      Width = 71
      Height = 17
      Caption = 'Dias resumo'
    end
    object cbStatus: TComboBox
      Left = 16
      Top = 48
      Width = 201
      Height = 25
      Style = csDropDownList
      TabOrder = 0
    end
    object edDataInicial: TEdit
      Left = 235
      Top = 48
      Width = 120
      Height = 25
      TabOrder = 1
    end
    object edDataFinal: TEdit
      Left = 373
      Top = 48
      Width = 120
      Height = 25
      TabOrder = 2
    end
    object edDias: TEdit
      Left = 511
      Top = 48
      Width = 79
      Height = 25
      TabOrder = 3
    end
    object btnConsultar: TButton
      Left = 610
      Top = 46
      Width = 121
      Height = 28
      Caption = 'Consultar Agora'
      TabOrder = 4
      OnClick = btnConsultarClick
    end
  end
  object gbResumo: TGroupBox
    Left = 16
    Top = 300
    Width = 1188
    Height = 105
    Caption = 'Resumo'
    TabOrder = 3
    object lblTotal: TLabel
      Left = 16
      Top = 29
      Width = 29
      Height = 17
      Caption = 'Total'
    end
    object lblAutorizadas: TLabel
      Left = 111
      Top = 29
      Width = 72
      Height = 17
      Caption = 'Autorizadas'
    end
    object lblContingencia: TLabel
      Left = 206
      Top = 29
      Width = 80
      Height = 17
      Caption = 'Contingencia'
    end
    object lblPendentes: TLabel
      Left = 301
      Top = 29
      Width = 65
      Height = 17
      Caption = 'Pendentes'
    end
    object lblRejeitadas: TLabel
      Left = 396
      Top = 29
      Width = 61
      Height = 17
      Caption = 'Rejeitadas'
    end
    object lblCanceladas: TLabel
      Left = 491
      Top = 29
      Width = 65
      Height = 17
      Caption = 'Canceladas'
    end
    object lblValorTotal: TLabel
      Left = 606
      Top = 29
      Width = 59
      Height = 17
      Caption = 'Valor total'
    end
    object lblValorCont: TLabel
      Left = 777
      Top = 29
      Width = 100
      Height = 17
      Caption = 'Valor contingencia'
    end
    object lblValorPend: TLabel
      Left = 968
      Top = 29
      Width = 85
      Height = 17
      Caption = 'Valor pendente'
    end
    object edTotal: TEdit
      Left = 16
      Top = 48
      Width = 79
      Height = 25
      ReadOnly = True
      TabOrder = 0
    end
    object edAutorizadas: TEdit
      Left = 111
      Top = 48
      Width = 79
      Height = 25
      ReadOnly = True
      TabOrder = 1
    end
    object edContingencia: TEdit
      Left = 206
      Top = 48
      Width = 79
      Height = 25
      ReadOnly = True
      TabOrder = 2
    end
    object edPendentes: TEdit
      Left = 301
      Top = 48
      Width = 79
      Height = 25
      ReadOnly = True
      TabOrder = 3
    end
    object edRejeitadas: TEdit
      Left = 396
      Top = 48
      Width = 79
      Height = 25
      ReadOnly = True
      TabOrder = 4
    end
    object edCanceladas: TEdit
      Left = 491
      Top = 48
      Width = 79
      Height = 25
      ReadOnly = True
      TabOrder = 5
    end
    object edValorTotal: TEdit
      Left = 606
      Top = 48
      Width = 151
      Height = 25
      ReadOnly = True
      TabOrder = 6
    end
    object edValorCont: TEdit
      Left = 777
      Top = 48
      Width = 171
      Height = 25
      ReadOnly = True
      TabOrder = 7
    end
    object edValorPend: TEdit
      Left = 968
      Top = 48
      Width = 171
      Height = 25
      ReadOnly = True
      TabOrder = 8
    end
  end
  object sgNotas: TStringGrid
    Left = 16
    Top = 417
    Width = 1188
    Height = 248
    ColCount = 10
    DefaultRowHeight = 22
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 4
  end
  object mmLog: TMemo
    Left = 16
    Top = 676
    Width = 1188
    Height = 69
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 5
  end
end
