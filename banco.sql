-- =====================================================================
-- BANCO DO PAINEL DA CRIS
-- Onde colar: no Supabase, abra o seu projeto, clique em "SQL Editor"
-- no menu da esquerda, depois em "New query". Cole TUDO isto e clique
-- em "Run". Pode rodar de novo quando quiser: nada é apagado e nada é
-- duplicado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. QUEM É A DONA
-- Esta função responde "sim" só quando quem está logado é a Cris.
-- Todas as trancas abaixo usam ela. Assim, mesmo que alguém consiga
-- criar uma conta no seu projeto, essa pessoa não lê nada seu.
-- ---------------------------------------------------------------------
create or replace function public.eh_a_cris()
returns boolean
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'contatocrisdallaccua@gmail.com'
$$;


-- ---------------------------------------------------------------------
-- 2. AS TABELAS
-- Cada tabela tem a coluna "exemplo": as linhas de exemplo vêm com ela
-- marcada, para você reconhecer e apagar depois.
-- ---------------------------------------------------------------------

-- Vídeos do portfólio. "nicho" é o nome da categoria do site
-- (Beleza, Moda, Casal...). "visivel" liga e desliga o vídeo no site.
create table if not exists public.videos (
  id        uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  titulo    text not null,
  link      text not null,
  nicho     text,
  formato   text,
  marca     text,
  destaque  text,
  ordem     integer not null default 0,
  visivel   boolean not null default true,
  exemplo   boolean not null default false
);

-- Sua base de contatos de empresa.
-- "origem" diz se a marca entrou pelo painel ou pelo formulário do site.
create table if not exists public.marcas (
  id             uuid primary key default gen_random_uuid(),
  criado_em      timestamptz not null default now(),
  nome           text not null,
  instagram      text,
  email          text,
  telefone       text,
  situacao       text not null default 'lead'
                 check (situacao in ('lead', 'conversando', 'cliente', 'parada')),
  obs            text,
  ultimo_contato date,
  origem         text not null default 'painel' check (origem in ('painel', 'site')),
  nicho          text,
  favorita       boolean not null default false,
  exemplo        boolean not null default false
);
-- campos novos (nicho e favorita): entram também numa tabela que já existia
alter table public.marcas add column if not exists nicho    text;
alter table public.marcas add column if not exists favorita boolean not null default false;

-- Sua agenda de gravar, editar e postar.
create table if not exists public.calendario (
  id        uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  titulo    text not null,
  marca     text,
  tipo      text not null default 'gravar' check (tipo in ('gravar', 'editar', 'postar')),
  data      date not null,
  status    text not null default 'a fazer' check (status in ('a fazer', 'feito')),
  exemplo   boolean not null default false
);

-- Suas campanhas. Os status seguem o funil, nesta ordem:
-- Briefing, Roteiro, Aprovação Roteiro, Gravação, Edição, Aprovado, Entregue.
create table if not exists public.campanhas (
  id         uuid primary key default gen_random_uuid(),
  criado_em  timestamptz not null default now(),
  campanha   text not null,
  cliente    text,
  tipo       text not null default 'Conteúdo' check (tipo in ('Conteúdo', 'Publicidade')),
  status     text not null default 'Briefing'
             check (status in ('Briefing', 'Roteiro', 'Aprovação Roteiro', 'Gravação', 'Edição', 'Aprovado', 'Entregue', 'Não fechou')),
  qtd        integer not null default 1 check (qtd >= 0),
  valor      numeric(12, 2) not null default 0 check (valor >= 0),
  prazo      date,
  pagamento  text not null default 'pendente' check (pagamento in ('pendente', 'pago', 'permuta')),
  ativa      boolean not null default true,
  favorita   boolean not null default false,
  fechada_em date,
  canal      text,
  exemplo    boolean not null default false
);
-- campos e opções novos (data em que fechou, de onde veio, "Não fechou" e "Permuta")
alter table public.campanhas add column if not exists fechada_em date;
alter table public.campanhas add column if not exists canal text;
alter table public.campanhas drop constraint if exists campanhas_status_check;
alter table public.campanhas add constraint campanhas_status_check
  check (status in ('Briefing', 'Roteiro', 'Aprovação Roteiro', 'Gravação', 'Edição', 'Aprovado', 'Entregue', 'Não fechou'));
alter table public.campanhas drop constraint if exists campanhas_pagamento_check;
alter table public.campanhas add constraint campanhas_pagamento_check
  check (pagamento in ('pendente', 'pago', 'permuta'));

-- O que você já marcou no checklist. Cada item tem uma chave de texto.
create table if not exists public.marcados (
  chave         text primary key,
  marcado       boolean not null default true,
  atualizado_em timestamptz not null default now()
);

-- As visitas do portfólio: só data, página e de onde veio.
-- Nada que identifique o visitante.
create table if not exists public.visitas (
  id     uuid primary key default gen_random_uuid(),
  data   timestamptz not null default now(),
  pagina text,
  origem text
);


-- ---------------------------------------------------------------------
-- 3. A TRANCA (RLS)
-- Liga a tranca em TODAS as tabelas. Com ela ligada, ninguém lê nem
-- escreve nada, a não ser pelas regras ("policies") escritas abaixo.
-- ---------------------------------------------------------------------
alter table public.videos     enable row level security;
alter table public.marcas     enable row level security;
alter table public.calendario enable row level security;
alter table public.campanhas  enable row level security;
alter table public.marcados   enable row level security;
alter table public.visitas    enable row level security;

-- Tira qualquer permissão antiga de quem está deslogado ("anon")
-- e devolve só o mínimo que o site precisa.
revoke all on public.videos, public.marcas, public.calendario,
              public.campanhas, public.marcados, public.visitas from anon;
grant select on public.videos  to anon;
grant insert on public.marcas  to anon;
grant insert on public.visitas to anon;

-- Quem está logado pode tentar mexer, mas as regras abaixo só deixam
-- passar a Cris.
grant select, insert, update, delete on public.videos, public.marcas,
      public.calendario, public.campanhas, public.marcados, public.visitas
      to authenticated;


-- 3.1 A Cris logada pode ler e escrever tudo, em todas as tabelas.
drop policy if exists "cris faz tudo" on public.videos;
create policy "cris faz tudo" on public.videos
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());

drop policy if exists "cris faz tudo" on public.marcas;
create policy "cris faz tudo" on public.marcas
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());

drop policy if exists "cris faz tudo" on public.calendario;
create policy "cris faz tudo" on public.calendario
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());

drop policy if exists "cris faz tudo" on public.campanhas;
create policy "cris faz tudo" on public.campanhas
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());

drop policy if exists "cris faz tudo" on public.marcados;
create policy "cris faz tudo" on public.marcados
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());

drop policy if exists "cris faz tudo" on public.visitas;
create policy "cris faz tudo" on public.visitas
  for all to authenticated using (public.eh_a_cris()) with check (public.eh_a_cris());


-- 3.2 EXCEÇÃO 1: o formulário do site pode CRIAR uma marca.
-- Só entra como Lead, marcada como vinda do site, e com tamanhos
-- limitados para ninguém encher a sua base de lixo. Ler, não pode.
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

-- 3.3 EXCEÇÃO 2: o site pode REGISTRAR uma visita. Ler, não pode.
drop policy if exists "site registra visita" on public.visitas;
create policy "site registra visita" on public.visitas
  for insert to anon
  with check (
    coalesce(char_length(pagina), 0) <= 300
    and coalesce(char_length(origem), 0) <= 100
    and data > now() - interval '1 hour'
    and data < now() + interval '1 hour'
  );

-- 3.4 O QUE O SITE PRECISA LER: os vídeos que já estão públicos no
-- portfólio. Só os marcados como visíveis e que não são exemplo.
-- Sem isso o site não consegue mostrar os vídeos do painel.
drop policy if exists "site le videos visiveis" on public.videos;
create policy "site le videos visiveis" on public.videos
  for select to anon
  using (visivel = true and exemplo = false);


-- ---------------------------------------------------------------------
-- 4. LINHAS DE EXEMPLO
-- Uma por lista, marcada como exemplo. Só entram se a tabela estiver
-- vazia, então rodar de novo não duplica nada.
-- ---------------------------------------------------------------------
insert into public.marcas (nome, instagram, email, telefone, situacao, obs, ultimo_contato, exemplo)
select 'Marca de exemplo (pode apagar)', '@marcaexemplo', 'contato@exemplo.com', '51 99999 0000',
       'lead', 'Linha de exemplo, só para mostrar o formato.', current_date, true
where not exists (select 1 from public.marcas);

insert into public.calendario (titulo, marca, tipo, data, status, exemplo)
select 'Exemplo: gravar vídeo de unboxing (pode apagar)', 'Marca de exemplo', 'gravar', current_date + 2, 'a fazer', true
where not exists (select 1 from public.calendario);

insert into public.campanhas (campanha, cliente, tipo, status, qtd, valor, prazo, pagamento, ativa, favorita, exemplo)
select 'Campanha de exemplo (pode apagar)', 'Marca de exemplo', 'Conteúdo', 'Briefing', 1, 0, current_date + 7, 'pendente', true, false, true
where not exists (select 1 from public.campanhas);


-- ---------------------------------------------------------------------
-- 5. OS SEUS VÍDEOS DE VERDADE
-- São os 64 vídeos que já estão no portfólio, na mesma ordem. Eles
-- entram junto com uma linha de exemplo escondida. Assim o site não
-- fica vazio quando passar a ler daqui. Também só entram se a tabela
-- estiver vazia.
-- ---------------------------------------------------------------------
insert into public.videos (titulo, link, nicho, marca, ordem, visivel, exemplo)
select 'Vídeo de exemplo (pode apagar)', 'https://youtube.com/shorts/XXXXXXXXXXX', 'Beleza', 'Marca de exemplo', 0, false, true
where not exists (select 1 from public.videos);

insert into public.videos (titulo, link, nicho, marca, ordem)
select v.titulo, v.link, v.nicho, v.marca, v.ordem
from (values
  ('Natura', 'https://youtube.com/shorts/zD1hoDCzj6U', 'Beleza', 'Natura', 10),
  ('D''Bianco', 'https://youtube.com/shorts/bl-uVFPBCrQ', 'Beleza', 'D''Bianco', 20),
  ('Aneethun', 'https://youtube.com/shorts/z1HS9XDP_eM', 'Beleza', 'Aneethun', 30),
  ('Revlon', 'https://youtube.com/shorts/9rv-USVCHTI', 'Beleza', 'Revlon', 40),
  ('Smart GR', 'https://youtube.com/shorts/XUV0xuQLdOk', 'Beleza', 'Smart GR', 50),
  ('Rildy', 'https://youtube.com/shorts/abf_HF8BpS4', 'Beleza', 'Rildy', 60),
  ('Boni Natural', 'https://youtube.com/shorts/b2fs5q5_Mrk', 'Beleza', 'Boni Natural', 70),
  ('Theoric', 'https://youtube.com/shorts/cKZx0V9Mjyo', 'Beleza', 'Theoric', 80),
  ('Villa Griffe', 'https://youtube.com/shorts/A5k4s6i9HQk', 'Moda', 'Villa Griffe', 90),
  ('Donna Guerriera', 'https://youtube.com/shorts/nw9udFnUMzk', 'Moda', 'Donna Guerriera', 100),
  ('Regina Rios', 'https://youtube.com/shorts/Jf8jCJnqexM', 'Moda', 'Regina Rios', 110),
  ('Opt Óculos', 'https://youtube.com/shorts/ng4ifWUSroE', 'Moda', 'Opt Óculos', 120),
  ('Camilove', 'https://youtube.com/shorts/ailKLJ6FEuI', 'Moda', 'Camilove', 130),
  ('Flowfa', 'https://youtube.com/shorts/zI0FIvigVpw', 'Moda', 'Flowfa', 140),
  ('Arroganza', 'https://youtube.com/shorts/cE6oJi5At4k', 'Moda', 'Arroganza', 150),
  ('Mirante', 'https://youtube.com/shorts/gvaQQKWIHlA', 'Moda', 'Mirante', 160),
  ('K&J Black', 'https://youtube.com/shorts/zhJ0foMyo7I', 'Casal', 'K&J Black', 170),
  ('Estar Mais', 'https://youtube.com/shorts/_yr7nX7WdbM', 'Casal', 'Estar Mais', 180),
  ('K&J Black', 'https://youtube.com/shorts/yWzNE078sI4', 'Casal', 'K&J Black', 190),
  ('Abelheiro', 'https://youtube.com/shorts/6pFGVvTulfI', 'Casal', 'Abelheiro', 200),
  ('Guará Plus', 'https://youtube.com/shorts/TJdWO2m20SY', 'Casal', 'Guará Plus', 210),
  ('K&J Black', 'https://youtube.com/shorts/MAVEJIcUScY', 'Casal', 'K&J Black', 220),
  ('Galiotto', 'https://youtube.com/shorts/imqL-dXzgKw', 'Casal', 'Galiotto', 230),
  ('K&J Black', 'https://youtube.com/shorts/45I1OxfoQAs', 'Casal', 'K&J Black', 240),
  ('Nutrata', 'https://youtube.com/shorts/efaA_zTnAKY', 'Fitness', 'Nutrata', 250),
  ('M.A.', 'https://youtube.com/shorts/T6ZFOHkZ8Po', 'Fitness', 'M.A.', 260),
  ('Trinys', 'https://youtube.com/shorts/lsX_kDsTtB8', 'Fitness', 'Trinys', 270),
  ('Estar Mais', 'https://youtube.com/shorts/Hhhd6151CmA', 'Fitness', 'Estar Mais', 280),
  ('Pump Gummy', 'https://youtube.com/shorts/9H7T5fyp9aI', 'Fitness', 'Pump Gummy', 290),
  ('Take & Go', 'https://youtube.com/shorts/fYUahv09jqo', 'Fitness', 'Take & Go', 300),
  ('Elementopuro', 'https://youtube.com/shorts/RIk1raRopgg', 'Fitness', 'Elementopuro', 310),
  ('Leg Gym', 'https://youtube.com/shorts/irZMV3XC2x4', 'Fitness', 'Leg Gym', 320),
  ('Hoomy', 'https://youtube.com/shorts/y_ZItWQhn6o', 'Casa e decoração', 'Hoomy', 330),
  ('Colormaq', 'https://youtube.com/shorts/kZCDDTGYTY4', 'Casa e decoração', 'Colormaq', 340),
  ('Cif', 'https://youtube.com/shorts/dZwXdSeEuYk', 'Casa e decoração', 'Cif', 350),
  ('AM Bordados', 'https://youtube.com/shorts/Tkjm74T4MEw', 'Casa e decoração', 'AM Bordados', 360),
  ('Vinagreen', 'https://youtube.com/shorts/vLKvo1v6EaA', 'Casa e decoração', 'Vinagreen', 370),
  ('AM Bordados', 'https://youtube.com/shorts/Vzx5y4TzXvM', 'Casa e decoração', 'AM Bordados', 380),
  ('Coala', 'https://youtube.com/shorts/00_qkUmpKQQ', 'Casa e decoração', 'Coala', 390),
  ('Colormaq', 'https://youtube.com/shorts/_nhPiQPW0X8', 'Casa e decoração', 'Colormaq', 400),
  ('Colormaq', 'https://youtube.com/shorts/e1UV_eFa4h4', 'Culinária', 'Colormaq', 410),
  ('Nectar', 'https://youtube.com/shorts/8mTcra2UhSs', 'Culinária', 'Nectar', 420),
  ('Galiotto', 'https://youtube.com/shorts/XSTzZKnPi20', 'Culinária', 'Galiotto', 430),
  ('Andorinha', 'https://youtube.com/shorts/2ftW_HKVlg4', 'Culinária', 'Andorinha', 440),
  ('Termolar', 'https://youtube.com/shorts/_pb2l_smDfo', 'Culinária', 'Termolar', 450),
  ('Colormaq', 'https://youtube.com/shorts/8z1hzUgrT8k', 'Culinária', 'Colormaq', 460),
  ('Luigi Limoncello', 'https://youtube.com/shorts/OD-EN0c2sR4', 'Culinária', 'Luigi Limoncello', 470),
  ('Galiotto', 'https://youtube.com/shorts/OLlSa90hbLQ', 'Culinária', 'Galiotto', 480),
  ('Sam''s Club', 'https://youtube.com/shorts/CACU5ZyaB6U', 'Experiências', 'Sam''s Club', 490),
  ('Casa Vilemar', 'https://youtube.com/shorts/6qB2m3ovgBg', 'Experiências', 'Casa Vilemar', 500),
  ('Sam''s Club', 'https://youtube.com/shorts/sB6sbfN6wTw', 'Experiências', 'Sam''s Club', 510),
  ('Andy Cabelos', 'https://youtube.com/shorts/NxxUqJpf4xE', 'Experiências', 'Andy Cabelos', 520),
  ('Hotel Valle D''Incanto', 'https://youtube.com/shorts/U5cx2KKzQDw', 'Experiências', 'Hotel Valle D''Incanto', 530),
  ('Sam''s Club', 'https://youtube.com/shorts/VapJSU8yV5Y', 'Experiências', 'Sam''s Club', 540),
  ('Loja Sirius', 'https://youtube.com/shorts/xG2Oj6HcpCU', 'Experiências', 'Loja Sirius', 550),
  ('Sam''s Club', 'https://youtube.com/shorts/ZX0PYCNYaAs', 'Experiências', 'Sam''s Club', 560),
  ('Gymnamic', 'https://youtube.com/shorts/mwCP6ZbEJrc', 'Tech, apps e educação', 'Gymnamic', 570),
  ('Duo Gourmet', 'https://youtube.com/shorts/7uKmJx0m3KM', 'Tech, apps e educação', 'Duo Gourmet', 580),
  ('Pitt Company', 'https://youtube.com/shorts/A-lost1LVLQ', 'Tech, apps e educação', 'Pitt Company', 590),
  ('iFood', 'https://youtube.com/shorts/2dpomLsC-P0', 'Tech, apps e educação', 'iFood', 600),
  ('TB Financial', 'https://youtube.com/shorts/XdiDPC7Fa5I', 'Tech, apps e educação', 'TB Financial', 610),
  ('Duo Gourmet', 'https://youtube.com/shorts/OXIk3mdaFB8', 'Tech, apps e educação', 'Duo Gourmet', 620),
  ('Inglês Sem Neura', 'https://youtube.com/shorts/yD940WiulXs', 'Tech, apps e educação', 'Inglês Sem Neura', 630),
  ('TotalPass', 'https://youtube.com/shorts/kQ64KmYQ4Yg', 'Tech, apps e educação', 'TotalPass', 640)
) as v (titulo, link, nicho, marca, ordem)
where not exists (select 1 from public.videos where exemplo = false);


-- ---------------------------------------------------------------------
-- 6. CONFERÊNCIA
-- Esta última linha mostra quantas linhas cada tabela tem. Se aparecer
-- a tabelinha com os números, deu tudo certo.
-- ---------------------------------------------------------------------
select
  (select count(*) from public.videos)     as videos,
  (select count(*) from public.marcas)     as marcas,
  (select count(*) from public.calendario) as calendario,
  (select count(*) from public.campanhas)  as campanhas,
  (select count(*) from public.marcados)   as marcados,
  (select count(*) from public.visitas)    as visitas;
