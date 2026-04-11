create table if not exists tenant_empresa (
  cnpj varchar(14) primary key,
  razao_social varchar(200),
  ativo boolean not null default true,
  created_at timestamp not null default current_timestamp,
  updated_at timestamp not null default current_timestamp
);

create table if not exists tenant_auth_token (
  id bigserial primary key,
  cnpj_empresa varchar(14) not null references tenant_empresa(cnpj) on delete cascade,
  token_sha256 char(64) not null,
  descricao varchar(120),
  ativo boolean not null default true,
  created_at timestamp not null default current_timestamp,
  updated_at timestamp not null default current_timestamp,
  constraint uq_tenant_auth_token unique (cnpj_empresa, token_sha256)
);

create index if not exists idx_tenant_auth_token_lookup
  on tenant_auth_token (cnpj_empresa, ativo);

create table if not exists agente_instalacao (
  instalacao_id varchar(80) primary key,
  cnpj_empresa varchar(14) not null references tenant_empresa(cnpj),
  nome_computador varchar(120),
  remote_ip varchar(60),
  last_seen_at timestamp not null default current_timestamp,
  created_at timestamp not null default current_timestamp
);

create index if not exists idx_agente_instalacao_cnpj
  on agente_instalacao (cnpj_empresa);

create table if not exists nfce_sync_lote (
  id bigserial primary key,
  cnpj_empresa varchar(14) not null references tenant_empresa(cnpj),
  instalacao_id varchar(80),
  quantidade integer not null,
  remote_ip varchar(60),
  raw_json jsonb not null,
  gerado_em timestamp null,
  created_at timestamp not null default current_timestamp
);

create index if not exists idx_nfce_sync_lote_cnpj_created_at
  on nfce_sync_lote (cnpj_empresa, created_at desc);

create table if not exists nfce_cabecalho_espelho (
  id bigserial primary key,
  cnpj_empresa varchar(14) not null references tenant_empresa(cnpj),
  source_id integer not null,
  instalacao_id varchar(80),
  nome_computador varchar(120),
  id_ecf_movimento integer,
  data_venda date,
  hora_venda varchar(8),
  status_venda varchar(40),
  num_nfce integer,
  serie_nfce integer,
  chave_acesso varchar(200),
  protocolo varchar(150),
  nfce_cancelada varchar(5),
  nfce_offline varchar(5),
  codigo_numerico_nfce integer,
  caminho_xml varchar(400),
  status_erro varchar(300),
  dhcont varchar(30),
  data_autorizacao date,
  valor_venda numeric(18,6),
  valor_final numeric(18,6),
  total_produtos numeric(18,6),
  total_documento numeric(18,6),
  base_icms numeric(18,6),
  icms numeric(18,6),
  pis numeric(18,6),
  cofins numeric(18,6),
  imposto numeric(18,6),
  imposto_estadual numeric(18,6),
  documento_cliente varchar(20),
  nome_cliente varchar(150),
  hash_incremento integer,
  status_operacional varchar(40),
  payload_json jsonb not null,
  remote_ip varchar(60),
  updated_at timestamp not null default current_timestamp,
  created_at timestamp not null default current_timestamp,
  constraint uq_nfce_espelho unique(cnpj_empresa, source_id)
);

create index if not exists idx_nfce_espelho_cnpj_data
  on nfce_cabecalho_espelho (cnpj_empresa, data_venda desc);

alter table agente_instalacao
  add column if not exists nome_computador varchar(120);

alter table nfce_cabecalho_espelho
  add column if not exists nome_computador varchar(120);

create index if not exists idx_nfce_espelho_cnpj_serie
  on nfce_cabecalho_espelho (cnpj_empresa, serie_nfce);

create index if not exists idx_nfce_espelho_cnpj_computador
  on nfce_cabecalho_espelho (cnpj_empresa, nome_computador);
