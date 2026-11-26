-- =====================================================================
-- PROSPECÇÃO POR E-MAIL
-- Onde colar: Supabase > seu projeto > SQL Editor > New query.
-- Cole tudo e clique em Run. Pode rodar mais de uma vez sem problema.
-- Não apaga nada do que já existe.
-- =====================================================================


-- 1. NA TABELA DE MARCAS: a caixinha de seleção.
--    Você marca hoje e dispara amanhã; a seleção fica guardada aqui.
alter table public.marcas add column if not exists selecionada boolean not null default false;


-- 2. REGISTRO DE ENVIOS: uma linha para cada e-mail que saiu (ou tentou sair).
--    Serve para saber quem recebeu, quem falhou e para não mandar duas vezes.
create table if not exists public.email_envios (
  id         uuid primary key default gen_random_uuid(),
  criado_em  timestamptz not null default now(),   -- a data e a hora do envio
  email      text not null,                        -- para quem foi
  marca      text,                                 -- o nome da marca, para o histórico
  assunto    text not null,                        -- o assunto do e-mail
  status     text not null check (status in ('ok', 'erro')),
  erro       text,                                 -- o motivo, quando deu errado
  resend_id  text,                                 -- o número que o Resend devolve
  via        text not null default 'resend' check (via in ('resend', 'gmail'))  -- gmail = modo rascunho
);
create index if not exists email_envios_email_idx   on public.email_envios (lower(email));
create index if not exists email_envios_assunto_idx on public.email_envios (assunto);


-- 3. DESCADASTRO: quem pediu para não receber mais. Nunca mais recebe.
create table if not exists public.email_optout (
  email      text primary key,                     -- sempre guardado em minúsculas
  criado_em  timestamptz not null default now()
);


-- 4. A TRANCA (RLS): só você, logada com o seu e-mail, lê e escreve.
--    Quem não está logado não enxerga nada. Usa a mesma regra do banco.sql.
alter table public.email_envios enable row level security;
alter table public.email_optout enable row level security;

revoke all on public.email_envios, public.email_optout from anon;
grant select, insert, update, delete on public.email_envios, public.email_optout to authenticated;

drop policy if exists "cris faz tudo" on public.email_envios;
create policy "cris faz tudo" on public.email_envios
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());

drop policy if exists "cris faz tudo" on public.email_optout;
create policy "cris faz tudo" on public.email_optout
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());


-- 5. CONFERÊNCIA: deve mostrar as duas tabelas e a coluna nova.
select
  (select count(*) from public.email_envios) as envios,
  (select count(*) from public.email_optout) as descadastros,
  (select count(*) from information_schema.columns
     where table_schema = 'public' and table_name = 'marcas' and column_name = 'selecionada') as coluna_selecionada;
