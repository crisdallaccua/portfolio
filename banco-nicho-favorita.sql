-- =====================================================================
-- NICHO E FAVORITA NA ABA MARCAS
-- Cole tudo no SQL Editor do Supabase e clique em Run. Pode rodar mais
-- de uma vez sem problema. Não apaga nada.
-- =====================================================================

-- 1. Dois campos novos na tabela de marcas
alter table public.marcas add column if not exists nicho    text;
alter table public.marcas add column if not exists favorita boolean not null default false;

-- 2. O formulário do site continua criando só Lead, e agora não pode
--    marcar favorita nem escolher nicho (isso é só seu, no painel).
drop policy if exists "formulario do site cria lead" on public.marcas;
create policy "formulario do site cria lead" on public.marcas
  for insert to anon
  with check (
    situacao = 'lead'
    and origem = 'site'
    and exemplo = false
    and favorita = false
    and nicho is null
    and char_length(nome) between 1 and 150
    and coalesce(char_length(email), 0) <= 200
    and coalesce(char_length(instagram), 0) <= 100
    and coalesce(char_length(telefone), 0) <= 40
    and coalesce(char_length(obs), 0) <= 4000
  );

-- 3. Conferência: deve mostrar os dois campos novos
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'marcas' and column_name in ('nicho', 'favorita');
