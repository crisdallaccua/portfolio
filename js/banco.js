/* =====================================================================
   LIGAÇÃO COM O SUPABASE (o banco de dados do painel)
   Este é o único lugar com o endereço e a chave. Todas as páginas usam
   este arquivo. A chave daqui é a PÚBLICA: ela pode ficar no site,
   porque quem protege os dados é a tranca (RLS) do banco.
   Nunca coloque aqui a chave secreta ("service_role" ou "secret").
   ===================================================================== */
window.BANCO = {
  url: "https://qcnhvmjweljdbqpoheyd.supabase.co",
  chave: "sb_publishable_BamNzy3pAnMnlAmzK-0OTg_-DrgGLDM",
  emailDaCris: "contatocrisdallaccua@gmail.com"
};

/* Nas páginas que carregam o Supabase pelo CDN (login e admin), já deixa
   o cliente pronto em window.sb. O portfólio não precisa disso: ele fala
   com o banco direto, para continuar leve. */
window.sb = (window.supabase && window.supabase.createClient)
  ? window.supabase.createClient(window.BANCO.url, window.BANCO.chave)
  : null;
