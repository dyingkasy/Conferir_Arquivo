package model

import (
	"encoding/json"
	"strings"
	"time"
)

type ConfigCheckRequest struct {
	CNPJEmpresa    string `json:"cnpj_empresa"`
	RazaoSocial    string `json:"razao_social"`
	InstalacaoID   string `json:"instalacao_id"`
	NomeComputador string `json:"nome_computador"`
}

type HeartbeatRequest struct {
	CNPJEmpresa  string `json:"cnpj_empresa"`
	InstalacaoID string `json:"instalacao_id"`
	NomeComputador string `json:"nome_computador"`
}

type LoteRequest struct {
	CNPJEmpresa  string            `json:"cnpj_empresa"`
	InstalacaoID string            `json:"instalacao_id"`
	NomeComputador string          `json:"nome_computador"`
	GeradoEm     string            `json:"gerado_em"`
	Quantidade   int               `json:"quantidade"`
	Notas        []json.RawMessage `json:"notas"`
}

type Tenant struct {
	CNPJ        string
	RazaoSocial string
}

type ResumoResponse struct {
	CNPJEmpresa               string  `json:"cnpj_empresa"`
	QuantidadeTotal           int64   `json:"quantidade_total"`
	QuantidadeTransmitida     int64   `json:"quantidade_transmitida"`
	QuantidadeContingencia    int64   `json:"quantidade_contingencia"`
	QuantidadeSemFiscal       int64   `json:"quantidade_sem_fiscal"`
	QuantidadeErro            int64   `json:"quantidade_erro"`
	ValorTotalDocumento       float64 `json:"valor_total_documento"`
	ValorTotalTransmitido     float64 `json:"valor_total_transmitido"`
	ValorTotalContingencia    float64 `json:"valor_total_contingencia"`
	ValorTotalSemFiscal       float64 `json:"valor_total_sem_fiscal"`
	ValorTotalErro            float64 `json:"valor_total_erro"`
	ValorBaseICMS             float64 `json:"valor_base_icms"`
	ValorICMS                 float64 `json:"valor_icms"`
	ValorPIS                  float64 `json:"valor_pis"`
	ValorCOFINS               float64 `json:"valor_cofins"`
	ValorImpostoFederal       float64 `json:"valor_imposto_federal"`
	ValorImpostoEstadual      float64 `json:"valor_imposto_estadual"`
}

type NFCeListItem struct {
	SourceID          int32    `json:"source_id"`
	InstalacaoID      string   `json:"instalacao_id"`
	NomeComputador    string   `json:"nome_computador"`
	GrupoConferencia  string   `json:"grupo_conferencia"`
	DataVenda         *string  `json:"data_venda,omitempty"`
	HoraVenda         string   `json:"hora_venda"`
	DataTransmissao   *string  `json:"data_transmissao,omitempty"`
	NumeroNFCe        *int32   `json:"num_nfce,omitempty"`
	SerieNFCe         *int32   `json:"serie_nfce,omitempty"`
	ChaveAcesso       string   `json:"chave_acesso"`
	Protocolo         string   `json:"protocolo"`
	StatusOperacional string   `json:"status_operacional"`
	StatusErro        string   `json:"status_erro"`
	NFCeOffline       string   `json:"nfce_offline"`
	NFCeCancelada     string   `json:"nfce_cancelada"`
	ValorDocumento    *float64 `json:"valor_documento,omitempty"`
	BaseICMS          *float64 `json:"base_icms,omitempty"`
	ICMS              *float64 `json:"icms,omitempty"`
	PIS               *float64 `json:"pis,omitempty"`
	COFINS            *float64 `json:"cofins,omitempty"`
	ImpostoFederal    *float64 `json:"imposto_federal,omitempty"`
	ImpostoEstadual   *float64 `json:"imposto_estadual,omitempty"`
	NomeCliente       string   `json:"nome_cliente"`
	DocumentoCliente  string   `json:"documento_cliente"`
}

type EmpresaListItem struct {
	CNPJ             string `json:"cnpj"`
	RazaoSocial      string `json:"razao_social"`
	QuantidadeXML    int64  `json:"quantidade_xml"`
	UltimaAtualizacao string `json:"ultima_atualizacao,omitempty"`
}

type FiltroValorItem struct {
	Valor string `json:"valor"`
}

type NotaPayload struct {
	Empresa           map[string]any `json:"empresa"`
	Venda             map[string]any `json:"venda"`
	StatusOperacional string         `json:"status_operacional"`
}

type NFCeEspelhoRow struct {
	CNPJEmpresa        string
	SourceID           int32
	InstalacaoID       string
	NomeComputador     string
	IDECFMovimento     *int32
	DataVenda          *time.Time
	HoraVenda          string
	StatusVenda        string
	NumNFCe            *int32
	SerieNFCe          *int32
	ChaveAcesso        string
	Protocolo          string
	NFCeCancelada      string
	NFCeOffline        string
	CodigoNumericoNFCe *int32
	CaminhoXML         string
	StatusErro         string
	DHCont             string
	DataAutorizacao    *time.Time
	ValorVenda         *float64
	ValorFinal         *float64
	TotalProdutos      *float64
	TotalDocumento     *float64
	BaseICMS           *float64
	ICMS               *float64
	PIS                *float64
	COFINS             *float64
	Imposto            *float64
	ImpostoEstadual    *float64
	DocumentoCliente   string
	NomeCliente        string
	HashIncremento     *int32
	StatusOperacional  string
	PayloadJSON        []byte
	RemoteIP           string
}

type NFeSaidaPayload struct {
	Empresa           map[string]any `json:"empresa"`
	Nota              map[string]any `json:"nota"`
	StatusOperacional string         `json:"status_operacional"`
}

type NFeSaidaEspelhoRow struct {
	CNPJEmpresa       string
	SourceID          int32
	InstalacaoID      string
	NomeComputador    string
	IDEmpresa         *int32
	NumeroNota        *int32
	SerieNotaFiscal   *int32
	SerieNota         string
	CodigoModelo      *int32
	TipoNota          *int32
	DataEmissao       *time.Time
	DataSaida         *time.Time
	HoraSaida         string
	ChaveAcesso       string
	Protocolo         string
	StatusCancelado   string
	StatusTransmitida string
	StatusRetorno     string
	CanceladaNF       string
	ValorTotal        *float64
	ValorProdutos     *float64
	Desconto          *float64
	ValorFrete        *float64
	ValorSeguro       *float64
	OutrasDespesas    *float64
	ValorOutro        *float64
	BaseICMS          *float64
	ValorICMS         *float64
	BaseST            *float64
	ValorST           *float64
	ValorIPI          *float64
	ValorPIS          *float64
	ValorCOFINS       *float64
	ValorPISST        *float64
	ValorCOFINSST     *float64
	Recibo            string
	Web               string
	TipoPagamento     *int32
	CodigoNumerico    *int32
	DocumentoCliente  string
	XMLPresente       bool
	HashIncremento    *int32
	StatusOperacional string
	PayloadJSON       []byte
	RemoteIP          string
}

func NormalizeDigits(value string) string {
	var b strings.Builder
	b.Grow(len(value))
	for _, ch := range value {
		if ch >= '0' && ch <= '9' {
			b.WriteRune(ch)
		}
	}
	return b.String()
}
