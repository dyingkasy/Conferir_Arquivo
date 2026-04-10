object FrmConfereArquivoOfficeMain: TFrmConfereArquivoOfficeMain
  Left = 0
  Top = 0
  Caption = 'Confere Arquivo - Painel Empresa'
  ClientHeight = 768
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1280
    Height = 64
    Align = alTop
    BevelOuter = bvNone
    Color = 3815994
    ParentBackground = False
    TabOrder = 0
    object lblTitulo: TLabel
      Left = 18
      Top = 10
      Width = 255
      Height = 25
      Caption = 'Confere Arquivo - Painel'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -20
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object lblSubtitulo: TLabel
      Left = 18
      Top = 37
      Width = 511
      Height = 15
      Caption = 'Conferencia de NFC-e transmitidas, contingencia, sem fiscal e totais por empresa.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15724527
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 64
    Width = 320
    Height = 704
    Align = alLeft
    BevelOuter = bvNone
    Padding.Left = 12
    Padding.Top = 10
    Padding.Right = 8
    Padding.Bottom = 12
    TabOrder = 1
    object gbConexao: TGroupBox
      Left = 12
      Top = 10
      Width = 300
      Height = 170
      Align = alTop
      Caption = 'Conexao'
      TabOrder = 0
      object lblApi: TLabel
        Left = 12
        Top = 24
        Width = 43
        Height = 15
        Caption = 'API URL'
      end
      object lblToken: TLabel
        Left = 12
        Top = 72
        Width = 31
        Height = 15
        Caption = 'Token'
      end
      object edApi: TEdit
        Left = 12
        Top = 41
        Width = 276
        Height = 23
        TabOrder = 0
      end
      object edToken: TEdit
        Left = 12
        Top = 89
        Width = 276
        Height = 23
        TabOrder = 1
      end
      object btnSalvar: TButton
        Left = 12
        Top = 126
        Width = 84
        Height = 28
        Caption = 'Salvar'
        TabOrder = 2
        OnClick = btnSalvarClick
      end
      object btnHealth: TButton
        Left = 106
        Top = 126
        Width = 84
        Height = 28
        Caption = 'Health'
        TabOrder = 3
        OnClick = btnHealthClick
      end
      object btnEmpresas: TButton
        Left = 200
        Top = 126
        Width = 88
        Height = 28
        Caption = 'Atualizar'
        TabOrder = 4
        OnClick = btnEmpresasClick
      end
    end
    object gbEmpresas: TGroupBox
      Left = 12
      Top = 180
      Width = 300
      Height = 512
      Align = alClient
      Caption = 'Empresas'
      TabOrder = 1
      object lblEmpresaFiltro: TLabel
        Left = 12
        Top = 25
        Width = 90
        Height = 15
        Caption = 'Filtro da empresa'
      end
      object lblQtdEmpresas: TLabel
        Left = 12
        Top = 70
        Width = 107
        Height = 15
        Caption = 'Empresas na lista: 0'
      end
      object edEmpresaFiltro: TEdit
        Left = 12
        Top = 42
        Width = 276
        Height = 23
        TabOrder = 0
        OnChange = edEmpresaFiltroChange
      end
      object lbEmpresas: TListBox
        Left = 12
        Top = 91
        Width = 276
        Height = 407
        ItemHeight = 15
        TabOrder = 1
        OnClick = lbEmpresasClick
      end
    end
  end
  object pnlConteudo: TPanel
    Left = 320
    Top = 64
    Width = 960
    Height = 704
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 10
    Padding.Right = 12
    Padding.Bottom = 12
    TabOrder = 2
    object gbFiltros: TGroupBox
      Left = 8
      Top = 10
      Width = 940
      Height = 74
      Align = alTop
      Caption = 'Filtros'
      TabOrder = 0
      object lblStatus: TLabel
        Left = 12
        Top = 23
        Width = 33
        Height = 15
        Caption = 'Status'
      end
      object lblDataInicial: TLabel
        Left = 238
        Top = 23
        Width = 57
        Height = 15
        Caption = 'Data inicial'
      end
      object lblDataFinal: TLabel
        Left = 352
        Top = 23
        Width = 50
        Height = 15
        Caption = 'Data final'
      end
      object lblDias: TLabel
        Left = 466
        Top = 23
        Width = 63
        Height = 15
        Caption = 'Dias resumo'
      end
      object cbStatus: TComboBox
        Left = 12
        Top = 40
        Width = 210
        Height = 23
        Style = csDropDownList
        TabOrder = 0
      end
      object edDataInicial: TEdit
        Left = 238
        Top = 40
        Width = 96
        Height = 23
        TabOrder = 1
      end
      object edDataFinal: TEdit
        Left = 352
        Top = 40
        Width = 96
        Height = 23
        TabOrder = 2
      end
      object edDias: TEdit
        Left = 466
        Top = 40
        Width = 64
        Height = 23
        TabOrder = 3
      end
      object btnConsultar: TButton
        Left = 546
        Top = 37
        Width = 126
        Height = 28
        Caption = 'Consultar Agora'
        TabOrder = 4
        OnClick = btnConsultarClick
      end
    end
    object gbResumo: TGroupBox
      Left = 8
      Top = 84
      Width = 940
      Height = 118
      Align = alTop
      Caption = 'Resumo Operacional'
      TabOrder = 1
      object lblTotal: TLabel
        Left = 12
        Top = 24
        Width = 25
        Height = 15
        Caption = 'Total'
      end
      object lblTransmitidas: TLabel
        Left = 102
        Top = 24
        Width = 66
        Height = 15
        Caption = 'Transmitidas'
      end
      object lblContingencia: TLabel
        Left = 192
        Top = 24
        Width = 72
        Height = 15
        Caption = 'Contingencia'
      end
      object lblSemFiscal: TLabel
        Left = 282
        Top = 24
        Width = 56
        Height = 15
        Caption = 'Sem fiscal'
      end
      object lblRejeitadas: TLabel
        Left = 372
        Top = 24
        Width = 56
        Height = 15
        Caption = 'Rejeitadas'
      end
      object lblCanceladas: TLabel
        Left = 462
        Top = 24
        Width = 60
        Height = 15
        Caption = 'Canceladas'
      end
      object lblValorTotal: TLabel
        Left = 12
        Top = 68
        Width = 52
        Height = 15
        Caption = 'Valor total'
      end
      object lblValorTransmitido: TLabel
        Left = 192
        Top = 68
        Width = 93
        Height = 15
        Caption = 'Valor transmitido'
      end
      object lblValorCont: TLabel
        Left = 372
        Top = 68
        Width = 92
        Height = 15
        Caption = 'Valor contingencia'
      end
    object lblValorSemFiscal: TLabel
      Left = 552
      Top = 68
      Width = 76
      Height = 15
      Caption = 'Valor sem fiscal'
    end
      object edTotal: TEdit
        Left = 12
        Top = 40
        Width = 74
        Height = 23
        ReadOnly = True
        TabOrder = 0
      end
      object edTransmitidas: TEdit
        Left = 102
        Top = 40
        Width = 74
        Height = 23
        ReadOnly = True
        TabOrder = 1
      end
      object edContingencia: TEdit
        Left = 192
        Top = 40
        Width = 74
        Height = 23
        ReadOnly = True
        TabOrder = 2
      end
      object edSemFiscal: TEdit
        Left = 282
        Top = 40
        Width = 74
        Height = 23
        ReadOnly = True
        TabOrder = 3
      end
      object edRejeitadas: TEdit
        Left = 372
        Top = 40
        Width = 74
        Height = 23
        ReadOnly = True
        TabOrder = 4
      end
      object edCanceladas: TEdit
        Left = 462
        Top = 40
        Width = 74
        Height = 23
        ReadOnly = True
        TabOrder = 5
      end
      object edValorTotal: TEdit
        Left = 12
        Top = 84
        Width = 160
        Height = 23
        ReadOnly = True
        TabOrder = 6
      end
      object edValorTransmitido: TEdit
        Left = 192
        Top = 84
        Width = 160
        Height = 23
        ReadOnly = True
        TabOrder = 7
      end
      object edValorCont: TEdit
        Left = 372
        Top = 84
        Width = 160
        Height = 23
        ReadOnly = True
        TabOrder = 8
      end
      object edValorSemFiscal: TEdit
        Left = 552
        Top = 84
        Width = 160
        Height = 23
        ReadOnly = True
        TabOrder = 9
      end
    end
    object gbTributos: TGroupBox
      Left = 8
      Top = 202
      Width = 940
      Height = 74
      Align = alTop
      Caption = 'Resumo Tributario'
      TabOrder = 2
      object lblTribBase: TLabel
        Left = 12
        Top = 22
        Width = 58
        Height = 15
        Caption = 'Base ICMS'
      end
      object lblTribICMS: TLabel
        Left = 168
        Top = 22
        Width = 29
        Height = 15
        Caption = 'ICMS'
      end
      object lblTribPIS: TLabel
        Left = 324
        Top = 22
        Width = 18
        Height = 15
        Caption = 'PIS'
      end
      object lblTribCOFINS: TLabel
        Left = 480
        Top = 22
        Width = 42
        Height = 15
        Caption = 'COFINS'
      end
      object lblTribFederal: TLabel
        Left = 636
        Top = 22
        Width = 75
        Height = 15
        Caption = 'Imp. Federal'
      end
      object lblTribEstadual: TLabel
        Left = 792
        Top = 22
        Width = 80
        Height = 15
        Caption = 'Imp. Estadual'
      end
      object edTribBase: TEdit
        Left = 12
        Top = 39
        Width = 144
        Height = 23
        ReadOnly = True
        TabOrder = 0
      end
      object edTribICMS: TEdit
        Left = 168
        Top = 39
        Width = 144
        Height = 23
        ReadOnly = True
        TabOrder = 1
      end
      object edTribPIS: TEdit
        Left = 324
        Top = 39
        Width = 144
        Height = 23
        ReadOnly = True
        TabOrder = 2
      end
      object edTribCOFINS: TEdit
        Left = 480
        Top = 39
        Width = 144
        Height = 23
        ReadOnly = True
        TabOrder = 3
      end
      object edTribFederal: TEdit
        Left = 636
        Top = 39
        Width = 144
        Height = 23
        ReadOnly = True
        TabOrder = 4
      end
      object edTribEstadual: TEdit
        Left = 792
        Top = 39
        Width = 136
        Height = 23
        ReadOnly = True
        TabOrder = 5
      end
    end
    object mmLog: TMemo
      Left = 8
      Top = 600
      Width = 940
      Height = 92
      Align = alBottom
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 3
    end
    object sgNotas: TStringGrid
      Left = 8
      Top = 276
      Width = 940
      Height = 324
      Align = alClient
      ColCount = 10
      DefaultRowHeight = 21
      FixedCols = 0
      RowCount = 2
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
      TabOrder = 2
      OnDrawCell = sgNotasDrawCell
    end
  end
end
