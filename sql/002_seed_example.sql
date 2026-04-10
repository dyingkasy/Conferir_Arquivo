insert into tenant_empresa (
  cnpj,
  razao_social,
  ativo
) values (
  '12345678000199',
  'EMPRESA EXEMPLO LTDA',
  true
)
on conflict (cnpj) do update
set razao_social = excluded.razao_social,
    ativo = excluded.ativo,
    updated_at = current_timestamp;

insert into tenant_auth_token (
  cnpj_empresa,
  token_sha256,
  descricao,
  ativo
) values (
  '12345678000199',
  '31838db399e588dc75f36d6b7aa9ff82b28674cfc3c1a6db8d6230b0f8fc89a3',
  'seed inicial',
  true
)
on conflict (cnpj_empresa, token_sha256) do update
set descricao = excluded.descricao,
    ativo = excluded.ativo,
    updated_at = current_timestamp;
