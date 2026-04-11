package store

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"conferir_arquivo/internal/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrUnauthorized = errors.New("unauthorized")

type Postgres struct {
	pool *pgxpool.Pool
}

func NewPostgres(ctx context.Context, databaseURL string) (*Postgres, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}
	cfg.MaxConns = 10
	cfg.MinConns = 1
	cfg.MaxConnLifetime = time.Hour
	cfg.MaxConnIdleTime = 15 * time.Minute
	cfg.HealthCheckPeriod = 30 * time.Second

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("open pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	return &Postgres{pool: pool}, nil
}

func (p *Postgres) Close() {
	p.pool.Close()
}

func (p *Postgres) Health(ctx context.Context) error {
	return p.pool.Ping(ctx)
}

func (p *Postgres) ValidateTenantToken(ctx context.Context, cnpj, token string) (model.Tenant, error) {
	cnpj = model.NormalizeDigits(cnpj)
	token = strings.TrimSpace(token)

	var tenant model.Tenant
	err := p.pool.QueryRow(ctx, `
		select te.cnpj, coalesce(te.razao_social, '')
		from tenant_empresa te
		join tenant_auth_token tat
		  on tat.cnpj_empresa = te.cnpj
		 and tat.ativo = true
		where te.cnpj = $1
		  and te.ativo = true
		  and tat.token_sha256 = $2
	`, cnpj, hashToken(token)).Scan(&tenant.CNPJ, &tenant.RazaoSocial)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return model.Tenant{}, ErrUnauthorized
		}
		return model.Tenant{}, err
	}

	return tenant, nil
}

func (p *Postgres) EnsureTenantToken(ctx context.Context, cnpj, token, razaoSocial string) (model.Tenant, error) {
	cnpj = model.NormalizeDigits(cnpj)
	token = strings.TrimSpace(token)
	razaoSocial = strings.TrimSpace(razaoSocial)
	if cnpj == "" || token == "" {
		return model.Tenant{}, errors.New("cnpj and token are required")
	}

	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return model.Tenant{}, err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		insert into tenant_empresa (cnpj, razao_social, ativo, created_at, updated_at)
		values ($1, nullif($2, ''), true, now(), now())
		on conflict (cnpj) do update
		set razao_social = coalesce(nullif(excluded.razao_social, ''), tenant_empresa.razao_social),
		    ativo = true,
		    updated_at = now()
	`, cnpj, razaoSocial)
	if err != nil {
		return model.Tenant{}, err
	}

	_, err = tx.Exec(ctx, `
		insert into tenant_auth_token (cnpj_empresa, token_sha256, descricao, ativo, created_at, updated_at)
		values ($1, $2, 'provisionado pelo agente', true, now(), now())
		on conflict (cnpj_empresa, token_sha256) do update
		set ativo = true,
		    updated_at = now()
	`, cnpj, hashToken(token))
	if err != nil {
		return model.Tenant{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return model.Tenant{}, err
	}

	return p.ValidateTenantToken(ctx, cnpj, token)
}

func (p *Postgres) SaveHeartbeat(ctx context.Context, cnpj, instalacaoID, nomeComputador, remoteIP string) error {
	cnpj = model.NormalizeDigits(cnpj)
	instalacaoID = strings.TrimSpace(instalacaoID)
	if instalacaoID == "" {
		return errors.New("instalacao_id is required")
	}

	_, err := p.pool.Exec(ctx, `
		insert into agente_instalacao (
			instalacao_id,
			cnpj_empresa,
			nome_computador,
			remote_ip,
			last_seen_at,
			created_at
		) values ($1, $2, $3, $4, now(), now())
		on conflict (instalacao_id) do update
		set cnpj_empresa = excluded.cnpj_empresa,
			nome_computador = excluded.nome_computador,
			remote_ip = excluded.remote_ip,
			last_seen_at = now()
	`, instalacaoID, cnpj, strings.TrimSpace(nomeComputador), trimRemoteIP(remoteIP))
	return err
}

func (p *Postgres) SaveLote(ctx context.Context, lote model.LoteRequest, token, remoteIP string) error {
	cnpj := model.NormalizeDigits(lote.CNPJEmpresa)
	instalacaoID := strings.TrimSpace(lote.InstalacaoID)
	if cnpj == "" || instalacaoID == "" {
		return errors.New("cnpj_empresa and instalacao_id are required")
	}
	if len(lote.Notas) == 0 {
		return errors.New("notas is required")
	}

	if _, err := p.EnsureTenantToken(ctx, cnpj, token, ""); err != nil {
		return err
	}

	rawPayload, err := json.Marshal(lote)
	if err != nil {
		return err
	}

	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if err := p.saveHeartbeatTx(ctx, tx, cnpj, instalacaoID, lote.NomeComputador, remoteIP); err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		insert into nfce_sync_lote (
			cnpj_empresa,
			instalacao_id,
			quantidade,
			remote_ip,
			raw_json,
			gerado_em,
			created_at
		) values ($1, $2, $3, $4, $5::jsonb, $6, now())
	`, cnpj, instalacaoID, lote.Quantidade, trimRemoteIP(remoteIP), string(rawPayload), parseTimestamp(lote.GeradoEm))
	if err != nil {
		return err
	}

	for _, rawNota := range lote.Notas {
		row, err := buildEspelhoRow(cnpj, instalacaoID, rawNota, remoteIP)
		if err != nil {
			return err
		}
		if err := p.upsertEspelho(ctx, tx, row); err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (p *Postgres) GetResumo(ctx context.Context, cnpj, token, dataInicial, dataFinal, serie, nomeComputador string, dias int) (model.ResumoResponse, error) {
	if dias <= 0 {
		dias = 7
	}
	cnpj = model.NormalizeDigits(cnpj)
	if _, err := p.ValidateTenantToken(ctx, cnpj, token); err != nil {
		return model.ResumoResponse{}, err
	}

	var resp model.ResumoResponse
	resp.CNPJEmpresa = cnpj
	baseSQL := `
		select
			count(*)::bigint,
			count(*) filter (where upper(coalesce(status_operacional, '')) in ('AUTORIZADA', 'CONTINGENCIA_AUTORIZADA'))::bigint,
			count(*) filter (where upper(coalesce(status_operacional, '')) in ('CONTINGENCIA', 'CONTINGENCIA_PENDENTE'))::bigint,
			count(*) filter (where upper(coalesce(status_operacional, '')) = 'PENDENTE_TRANSMISSAO')::bigint,
			count(*) filter (where upper(coalesce(status_operacional, '')) in ('REJEITADA', 'CANCELADA'))::bigint,
			coalesce(sum(valor_final), 0)::float8,
			coalesce(sum(case when upper(coalesce(status_operacional, '')) in ('AUTORIZADA', 'CONTINGENCIA_AUTORIZADA') then valor_final else 0 end), 0)::float8,
			coalesce(sum(case when upper(coalesce(status_operacional, '')) in ('CONTINGENCIA', 'CONTINGENCIA_PENDENTE') then valor_final else 0 end), 0)::float8,
			coalesce(sum(case when upper(coalesce(status_operacional, '')) = 'PENDENTE_TRANSMISSAO' then valor_final else 0 end), 0)::float8,
			coalesce(sum(case when upper(coalesce(status_operacional, '')) in ('REJEITADA', 'CANCELADA') then valor_final else 0 end), 0)::float8,
			coalesce(sum(base_icms), 0)::float8,
			coalesce(sum(icms), 0)::float8,
			coalesce(sum(pis), 0)::float8,
			coalesce(sum(cofins), 0)::float8,
			coalesce(sum(imposto), 0)::float8,
			coalesce(sum(imposto_estadual), 0)::float8
		from nfce_cabecalho_espelho
		where cnpj_empresa = $1
	`
	args := []any{cnpj}
	argPos := 2

	if strings.TrimSpace(dataInicial) != "" {
		baseSQL += fmt.Sprintf(" and coalesce(data_venda, current_date) >= $%d", argPos)
		args = append(args, dataInicial)
		argPos++
	}
	if strings.TrimSpace(dataFinal) != "" {
		baseSQL += fmt.Sprintf(" and coalesce(data_venda, current_date) <= $%d", argPos)
		args = append(args, dataFinal)
		argPos++
	}
	if strings.TrimSpace(serie) != "" {
		baseSQL += fmt.Sprintf(" and coalesce(serie_nfce, 0) = $%d", argPos)
		args = append(args, strings.TrimSpace(serie))
		argPos++
	}
	if strings.TrimSpace(nomeComputador) != "" {
		baseSQL += fmt.Sprintf(" and upper(coalesce(nome_computador, '')) = upper($%d)", argPos)
		args = append(args, strings.TrimSpace(nomeComputador))
		argPos++
	}
	if strings.TrimSpace(dataInicial) == "" && strings.TrimSpace(dataFinal) == "" {
		baseSQL += fmt.Sprintf(" and coalesce(data_venda, current_date) >= current_date - ($%d::int)", argPos)
		args = append(args, dias)
	}

	err := p.pool.QueryRow(ctx, baseSQL, args...).Scan(
		&resp.QuantidadeTotal,
		&resp.QuantidadeTransmitida,
		&resp.QuantidadeContingencia,
		&resp.QuantidadeSemFiscal,
		&resp.QuantidadeErro,
		&resp.ValorTotalDocumento,
		&resp.ValorTotalTransmitido,
		&resp.ValorTotalContingencia,
		&resp.ValorTotalSemFiscal,
		&resp.ValorTotalErro,
		&resp.ValorBaseICMS,
		&resp.ValorICMS,
		&resp.ValorPIS,
		&resp.ValorCOFINS,
		&resp.ValorImpostoFederal,
		&resp.ValorImpostoEstadual,
	)
	return resp, err
}

func (p *Postgres) ListEmpresas(ctx context.Context, token string) ([]model.EmpresaListItem, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, errors.New("token is required")
	}

	rows, err := p.pool.Query(ctx, `
		select te.cnpj,
		       coalesce(te.razao_social, '') as razao_social,
		       count(ne.id)::bigint as quantidade_xml,
		       coalesce(to_char(max(ne.updated_at), 'YYYY-MM-DD HH24:MI:SS'), '') as ultima_atualizacao
		  from tenant_empresa te
		  join tenant_auth_token tat
		    on tat.cnpj_empresa = te.cnpj
		   and tat.ativo = true
		   and tat.token_sha256 = $1
		  join nfce_cabecalho_espelho ne
		    on ne.cnpj_empresa = te.cnpj
		 where te.ativo = true
		 group by te.cnpj, te.razao_social
		 order by te.razao_social, te.cnpj
	`, hashToken(token))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.EmpresaListItem, 0)
	for rows.Next() {
		var item model.EmpresaListItem
		if err := rows.Scan(&item.CNPJ, &item.RazaoSocial, &item.QuantidadeXML, &item.UltimaAtualizacao); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (p *Postgres) ListNFCe(ctx context.Context, cnpj, token, status, dataInicial, dataFinal, serie, nomeComputador string, limit int) ([]model.NFCeListItem, error) {
	cnpj = model.NormalizeDigits(cnpj)
	if _, err := p.ValidateTenantToken(ctx, cnpj, token); err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 500 {
		limit = 200
	}

	baseSQL := `
		select source_id, instalacao_id, coalesce(nome_computador, ''),
		       case
		         when upper(coalesce(status_operacional, '')) in ('AUTORIZADA', 'CONTINGENCIA_AUTORIZADA') then 'TRANSMITIDA'
		         when upper(coalesce(status_operacional, '')) in ('REJEITADA', 'CANCELADA') then 'ERRO'
		         when upper(coalesce(status_operacional, '')) in ('CONTINGENCIA', 'CONTINGENCIA_PENDENTE') then 'CONTINGENCIA'
		         else 'SEM_FISCAL'
		       end as grupo_conferencia,
		       data_venda, hora_venda, data_autorizacao, num_nfce, serie_nfce, chave_acesso, protocolo,
		       status_operacional, status_erro, nfce_offline, nfce_cancelada, valor_final, base_icms, icms, pis, cofins, imposto, imposto_estadual, nome_cliente, documento_cliente
		from nfce_cabecalho_espelho
		where cnpj_empresa = $1
	`
	args := []any{cnpj}
	argPos := 2

	if strings.TrimSpace(status) != "" {
		status = strings.ToUpper(strings.TrimSpace(status))
		switch status {
		case "TRANSMITIDA":
			baseSQL += " and upper(coalesce(status_operacional, '')) in ('AUTORIZADA', 'CONTINGENCIA_AUTORIZADA')"
		case "CONTINGENCIA":
			baseSQL += " and upper(coalesce(status_operacional, '')) in ('CONTINGENCIA', 'CONTINGENCIA_PENDENTE')"
		case "SEM_FISCAL":
			baseSQL += " and upper(coalesce(status_operacional, '')) = 'PENDENTE_TRANSMISSAO'"
		case "ERRO":
			baseSQL += " and upper(coalesce(status_operacional, '')) in ('REJEITADA', 'CANCELADA')"
		default:
			baseSQL += fmt.Sprintf(" and status_operacional = $%d", argPos)
			args = append(args, status)
			argPos++
		}
	}
	if strings.TrimSpace(dataInicial) != "" {
		baseSQL += fmt.Sprintf(" and data_venda >= $%d", argPos)
		args = append(args, dataInicial)
		argPos++
	}
	if strings.TrimSpace(dataFinal) != "" {
		baseSQL += fmt.Sprintf(" and data_venda <= $%d", argPos)
		args = append(args, dataFinal)
		argPos++
	}
	if strings.TrimSpace(serie) != "" {
		baseSQL += fmt.Sprintf(" and coalesce(serie_nfce, 0) = $%d", argPos)
		args = append(args, strings.TrimSpace(serie))
		argPos++
	}
	if strings.TrimSpace(nomeComputador) != "" {
		baseSQL += fmt.Sprintf(" and upper(coalesce(nome_computador, '')) = upper($%d)", argPos)
		args = append(args, strings.TrimSpace(nomeComputador))
		argPos++
	}

	baseSQL += fmt.Sprintf(" order by coalesce(data_venda, current_date) desc, source_id desc limit $%d", argPos)
	args = append(args, limit)

	rows, err := p.pool.Query(ctx, baseSQL, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.NFCeListItem, 0, limit)
	for rows.Next() {
		var item model.NFCeListItem
		var dataVenda *time.Time
		var dataTransmissao *time.Time
		var valorDoc *float64
		var baseICMS *float64
		var icms *float64
		var pis *float64
		var cofins *float64
		var impostoFederal *float64
		var impostoEstadual *float64
		if err := rows.Scan(
			&item.SourceID,
			&item.InstalacaoID,
			&item.NomeComputador,
			&item.GrupoConferencia,
			&dataVenda,
			&item.HoraVenda,
			&dataTransmissao,
			&item.NumeroNFCe,
			&item.SerieNFCe,
			&item.ChaveAcesso,
			&item.Protocolo,
			&item.StatusOperacional,
			&item.StatusErro,
			&item.NFCeOffline,
			&item.NFCeCancelada,
			&valorDoc,
			&baseICMS,
			&icms,
			&pis,
			&cofins,
			&impostoFederal,
			&impostoEstadual,
			&item.NomeCliente,
			&item.DocumentoCliente,
		); err != nil {
			return nil, err
		}
		if dataVenda != nil {
			v := dataVenda.Format("2006-01-02")
			item.DataVenda = &v
		}
		if dataTransmissao != nil {
			v := dataTransmissao.Format("2006-01-02")
			item.DataTransmissao = &v
		}
		item.ValorDocumento = valorDoc
		item.BaseICMS = baseICMS
		item.ICMS = icms
		item.PIS = pis
		item.COFINS = cofins
		item.ImpostoFederal = impostoFederal
		item.ImpostoEstadual = impostoEstadual
		items = append(items, item)
	}
	return items, rows.Err()
}

func (p *Postgres) ListSeries(ctx context.Context, cnpj, token string) ([]model.FiltroValorItem, error) {
	cnpj = model.NormalizeDigits(cnpj)
	if _, err := p.ValidateTenantToken(ctx, cnpj, token); err != nil {
		return nil, err
	}

	rows, err := p.pool.Query(ctx, `
		select distinct trim(coalesce(serie_nfce::text, ''))
		from nfce_cabecalho_espelho
		where cnpj_empresa = $1
		  and coalesce(serie_nfce, 0) > 0
		order by 1
	`, cnpj)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.FiltroValorItem, 0)
	for rows.Next() {
		var item model.FiltroValorItem
		if err := rows.Scan(&item.Valor); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (p *Postgres) ListComputadores(ctx context.Context, cnpj, token string) ([]model.FiltroValorItem, error) {
	cnpj = model.NormalizeDigits(cnpj)
	if _, err := p.ValidateTenantToken(ctx, cnpj, token); err != nil {
		return nil, err
	}

	rows, err := p.pool.Query(ctx, `
		select distinct trim(coalesce(nome_computador, ''))
		from nfce_cabecalho_espelho
		where cnpj_empresa = $1
		  and trim(coalesce(nome_computador, '')) <> ''
		order by 1
	`, cnpj)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.FiltroValorItem, 0)
	for rows.Next() {
		var item model.FiltroValorItem
		if err := rows.Scan(&item.Valor); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (p *Postgres) saveHeartbeatTx(ctx context.Context, tx pgx.Tx, cnpj, instalacaoID, nomeComputador, remoteIP string) error {
	_, err := tx.Exec(ctx, `
		insert into agente_instalacao (
			instalacao_id,
			cnpj_empresa,
			nome_computador,
			remote_ip,
			last_seen_at,
			created_at
		) values ($1, $2, $3, $4, now(), now())
		on conflict (instalacao_id) do update
		set cnpj_empresa = excluded.cnpj_empresa,
			nome_computador = excluded.nome_computador,
			remote_ip = excluded.remote_ip,
			last_seen_at = now()
	`, instalacaoID, cnpj, strings.TrimSpace(nomeComputador), trimRemoteIP(remoteIP))
	return err
}

func (p *Postgres) upsertEspelho(ctx context.Context, tx pgx.Tx, row model.NFCeEspelhoRow) error {
	_, err := tx.Exec(ctx, `
		insert into nfce_cabecalho_espelho (
			cnpj_empresa,
			source_id,
			instalacao_id,
			nome_computador,
			id_ecf_movimento,
			data_venda,
			hora_venda,
			status_venda,
			num_nfce,
			serie_nfce,
			chave_acesso,
			protocolo,
			nfce_cancelada,
			nfce_offline,
			codigo_numerico_nfce,
			caminho_xml,
			status_erro,
			dhcont,
			data_autorizacao,
			valor_venda,
			valor_final,
			total_produtos,
			total_documento,
			base_icms,
			icms,
			pis,
			cofins,
			imposto,
			imposto_estadual,
			documento_cliente,
			nome_cliente,
			hash_incremento,
			status_operacional,
			payload_json,
			remote_ip,
			updated_at,
			created_at
		) values (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
			$11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
			$21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
			$31, $32, $33, $34::jsonb, $35, now(), now()
		)
		on conflict (cnpj_empresa, source_id) do update set
			instalacao_id = excluded.instalacao_id,
			nome_computador = excluded.nome_computador,
			id_ecf_movimento = excluded.id_ecf_movimento,
			data_venda = excluded.data_venda,
			hora_venda = excluded.hora_venda,
			status_venda = excluded.status_venda,
			num_nfce = excluded.num_nfce,
			serie_nfce = excluded.serie_nfce,
			chave_acesso = excluded.chave_acesso,
			protocolo = excluded.protocolo,
			nfce_cancelada = excluded.nfce_cancelada,
			nfce_offline = excluded.nfce_offline,
			codigo_numerico_nfce = excluded.codigo_numerico_nfce,
			caminho_xml = excluded.caminho_xml,
			status_erro = excluded.status_erro,
			dhcont = excluded.dhcont,
			data_autorizacao = excluded.data_autorizacao,
			valor_venda = excluded.valor_venda,
			valor_final = excluded.valor_final,
			total_produtos = excluded.total_produtos,
			total_documento = excluded.total_documento,
			base_icms = excluded.base_icms,
			icms = excluded.icms,
			pis = excluded.pis,
			cofins = excluded.cofins,
			imposto = excluded.imposto,
			imposto_estadual = excluded.imposto_estadual,
			documento_cliente = excluded.documento_cliente,
			nome_cliente = excluded.nome_cliente,
			hash_incremento = excluded.hash_incremento,
			status_operacional = excluded.status_operacional,
			payload_json = excluded.payload_json,
			remote_ip = excluded.remote_ip,
			updated_at = now()
	`, row.CNPJEmpresa, row.SourceID, row.InstalacaoID, strings.TrimSpace(row.NomeComputador), row.IDECFMovimento, row.DataVenda, row.HoraVenda, row.StatusVenda,
		row.NumNFCe, row.SerieNFCe, row.ChaveAcesso, row.Protocolo, row.NFCeCancelada, row.NFCeOffline, row.CodigoNumericoNFCe,
		row.CaminhoXML, row.StatusErro, row.DHCont, row.DataAutorizacao, row.ValorVenda, row.ValorFinal, row.TotalProdutos,
		row.TotalDocumento, row.BaseICMS, row.ICMS, row.PIS, row.COFINS, row.Imposto, row.ImpostoEstadual, row.DocumentoCliente,
		row.NomeCliente, row.HashIncremento, row.StatusOperacional, string(row.PayloadJSON), trimRemoteIP(row.RemoteIP))
	return err
}

func buildEspelhoRow(cnpj, instalacaoID string, rawNota []byte, remoteIP string) (model.NFCeEspelhoRow, error) {
	var nota model.NotaPayload
	if err := json.Unmarshal(rawNota, &nota); err != nil {
		return model.NFCeEspelhoRow{}, fmt.Errorf("invalid nota payload: %w", err)
	}
	var noteRoot map[string]any
	if err := json.Unmarshal(rawNota, &noteRoot); err != nil {
		return model.NFCeEspelhoRow{}, fmt.Errorf("invalid nota root payload: %w", err)
	}

	venda := nota.Venda
	if venda == nil {
		return model.NFCeEspelhoRow{}, errors.New("nota sem objeto venda")
	}

	sourceID, ok := getInt32(venda, "source_id")
	if !ok || sourceID <= 0 {
		return model.NFCeEspelhoRow{}, errors.New("source_id is required")
	}

	row := model.NFCeEspelhoRow{
		CNPJEmpresa:      cnpj,
		SourceID:         sourceID,
		InstalacaoID:     instalacaoID,
		NomeComputador:   firstNonEmpty(getString(venda, "nome_computador"), getStringMap(noteRoot, "nome_computador")),
		HoraVenda:        getString(venda, "hora_venda"),
		StatusVenda:      getString(venda, "status_venda"),
		ChaveAcesso:      getString(venda, "chave_acesso"),
		Protocolo:        getString(venda, "protocolo"),
		NFCeCancelada:    getString(venda, "nfce_cancelada"),
		NFCeOffline:      getString(venda, "nfce_offline"),
		CaminhoXML:       getString(venda, "caminho_xml"),
		StatusErro:       truncate(getString(venda, "status_erro"), 300),
		DHCont:           getString(venda, "dhcont"),
		DocumentoCliente: getString(venda, "documento_cliente"),
		NomeCliente:      truncate(getString(venda, "nome_cliente"), 150),
		PayloadJSON: rawNota,
		RemoteIP:    remoteIP,
	}

	if value, ok := getInt32(venda, "id_ecf_movimento"); ok {
		row.IDECFMovimento = &value
	}
	if value, ok := getInt32(venda, "num_nfce"); ok {
		row.NumNFCe = &value
	}
	if value, ok := getInt32(venda, "serie_nfce"); ok {
		row.SerieNFCe = &value
	}
	if value, ok := getInt32(venda, "codigo_numerico_nfce"); ok {
		row.CodigoNumericoNFCe = &value
	}
	if value, ok := getInt32(venda, "hash_incremento"); ok {
		row.HashIncremento = &value
	}
	if row.HashIncremento == nil {
		if value, ok := getInt32Map(noteRoot, "hash_incremento"); ok {
			row.HashIncremento = &value
		}
	}

	if value, ok := parseDate(getString(venda, "data_venda")); ok {
		row.DataVenda = &value
	}
	if value, ok := parseDate(getString(venda, "data_autorizacao")); ok {
		row.DataAutorizacao = &value
	}

	for key, target := range map[string]**float64{
		"valor_venda":      &row.ValorVenda,
		"valor_final":      &row.ValorFinal,
		"total_produtos":   &row.TotalProdutos,
		"total_documento":  &row.TotalDocumento,
		"base_icms":        &row.BaseICMS,
		"icms":             &row.ICMS,
		"pis":              &row.PIS,
		"cofins":           &row.COFINS,
		"imposto":          &row.Imposto,
		"imposto_estadual": &row.ImpostoEstadual,
	} {
		if value, ok := getFloat64(venda, key); ok {
			*target = &value
		}
	}

	row.StatusOperacional = normalizeIncomingStatus(nota.StatusOperacional)
	if row.StatusOperacional == "" {
		row.StatusOperacional = classifyStatus(row)
	}

	return row, nil
}

func normalizeIncomingStatus(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "AUTORIZADA", "CONTINGENCIA_AUTORIZADA", "CONTINGENCIA", "CONTINGENCIA_PENDENTE", "PENDENTE_TRANSMISSAO", "REJEITADA", "CANCELADA":
		return strings.ToUpper(strings.TrimSpace(value))
	default:
		return ""
	}
}

func classifyStatus(row model.NFCeEspelhoRow) string {
	hasProtocol := strings.TrimSpace(row.Protocolo) != "" || row.DataAutorizacao != nil
	isCanceled := strings.TrimSpace(row.NFCeCancelada) != "" && !strings.EqualFold(strings.TrimSpace(row.NFCeCancelada), "N")
	hasError := strings.TrimSpace(row.StatusErro) != ""
	isOffline := strings.EqualFold(strings.TrimSpace(row.NFCeOffline), "S") || strings.TrimSpace(row.DHCont) != ""
	hasNumero := row.NumNFCe != nil && *row.NumNFCe > 0
	hasKey := strings.TrimSpace(row.ChaveAcesso) != ""

	if !(hasNumero || hasKey) {
		return "IGNORADA"
	}
	if isCanceled {
		return "CANCELADA"
	}
	if hasProtocol {
		return "AUTORIZADA"
	}
	if hasError {
		return "REJEITADA"
	}
	if isOffline {
		return "CONTINGENCIA_PENDENTE"
	}
	if hasNumero {
		return "PENDENTE_TRANSMISSAO"
	}
	return "IGNORADA"
}

func getString(values map[string]any, key string) string {
	if values == nil {
		return ""
	}
	value, ok := values[key]
	if !ok || value == nil {
		return ""
	}
	switch typed := value.(type) {
	case string:
		return strings.TrimSpace(typed)
	default:
		return strings.TrimSpace(fmt.Sprint(typed))
	}
}

func getStringMap(values map[string]any, key string) string {
	return getString(values, key)
}

func getInt32(values map[string]any, key string) (int32, bool) {
	if values == nil {
		return 0, false
	}
	return toInt32(values[key])
}

func getInt32Map(values map[string]any, key string) (int32, bool) {
	if values == nil {
		return 0, false
	}
	return toInt32(values[key])
}

func toInt32(value any) (int32, bool) {
	switch typed := value.(type) {
	case float64:
		return int32(typed), true
	case int:
		return int32(typed), true
	case int32:
		return typed, true
	case int64:
		return int32(typed), true
	case json.Number:
		v, err := typed.Int64()
		if err == nil {
			return int32(v), true
		}
	case string:
		if strings.TrimSpace(typed) == "" {
			return 0, false
		}
		v, err := strconv.ParseInt(strings.TrimSpace(typed), 10, 32)
		if err == nil {
			return int32(v), true
		}
	}
	return 0, false
}

func getFloat64(values map[string]any, key string) (float64, bool) {
	if values == nil {
		return 0, false
	}
	switch typed := values[key].(type) {
	case float64:
		return typed, true
	case json.Number:
		v, err := typed.Float64()
		if err == nil {
			return v, true
		}
	case string:
		clean := strings.TrimSpace(strings.ReplaceAll(typed, ",", "."))
		if clean == "" {
			return 0, false
		}
		v, err := strconv.ParseFloat(clean, 64)
		if err == nil {
			return v, true
		}
	}
	return 0, false
}

func parseDate(value string) (time.Time, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, false
	}
	layouts := []string{
		time.RFC3339,
		"2006-01-02",
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05",
	}
	for _, layout := range layouts {
		parsed, err := time.Parse(layout, value)
		if err == nil {
			return parsed.UTC(), true
		}
	}
	return time.Time{}, false
}

func parseTimestamp(value string) any {
	if parsed, ok := parseDate(value); ok {
		return parsed
	}
	return nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(token)))
	return fmt.Sprintf("%x", sum)
}

func trimRemoteIP(value string) string {
	value = strings.TrimSpace(value)
	if host, _, err := net.SplitHostPort(value); err == nil {
		value = host
	}
	if len(value) > 60 {
		return value[:60]
	}
	return value
}

func truncate(value string, limit int) string {
	if len(value) <= limit {
		return value
	}
	return value[:limit]
}
