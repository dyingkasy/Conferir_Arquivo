create table if not exists tenant_empresa (
  cnpj varchar(14) primary key,
  api_token varchar(200) not null,
  razao_social varchar(200),
  ativo boolean not null default true,
  created_at timestamp not null default current_timestamp,
  updated_at timestamp not null default current_timestamp
);

create table if not exists agente_instalacao (
  instalacao_id varchar(80) primary key,
  cnpj_empresa varchar(14) not null,
  remote_ip varchar(60),
  last_seen_at timestamp not null default current_timestamp,
  created_at timestamp not null default current_timestamp
);

create table if not exists nfce_sync_lote (
  id bigserial primary key,
  cnpj_empresa varchar(14) not null,
  instalacao_id varchar(80),
  quantidade integer not null,
  remote_ip varchar(60),
  raw_json jsonb not null,
  created_at timestamp not null default current_timestamp
);

create table if not exists nfce_cabecalho_espelho (
  id bigserial primary key,
  cnpj_empresa varchar(14) not null,
  source_id integer not null,
  instalacao_id varchar(80),
  id_ecf_movimento integer,
  data_venda date,
  hora_venda varchar(8),
  status_venda varchar(5),
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
