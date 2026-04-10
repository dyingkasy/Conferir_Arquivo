package model

import (
	"encoding/json"
	"strings"
	"time"
)

type ConfigCheckRequest struct {
	CNPJEmpresa  string `json:"cnpj_empresa"`
	RazaoSocial  string `json:"razao_social"`
	InstalacaoID string `json:"instalacao_id"`
}

type HeartbeatRequest struct {
	CNPJEmpresa  string `json:"cnpj_empresa"`
	InstalacaoID string `json:"instalacao_id"`
}

type LoteRequest struct {
	CNPJEmpresa  string            `json:"cnpj_empresa"`
	InstalacaoID string            `json:"instalacao_id"`
	GeradoEm     string            `json:"gerado_em"`
	Quantidade   int               `json:"quantidade"`
	Notas        []json.RawMessage `json:"notas"`
}

type Tenant struct {
	CNPJ        string
	RazaoSocial string
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
