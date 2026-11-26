// =====================================================================
// FUNÇÃO enviar-emails (o "carteiro" da aba Prospecção)
// Roda no Supabase (Edge Functions) e manda os e-mails pelo Resend.
//
// A chave do Resend NÃO fica aqui. Ela fica guardada como segredo da
// função no painel do Supabase, com o nome RESEND_API_KEY.
// Opcional: o segredo EMAIL_FROM com o remetente, por exemplo
//   Cris Dall' Accua <contato@crisdallaccua.com>
// (só funciona depois que o domínio estiver verificado no Resend).
// =====================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MEU_EMAIL = "contatocrisdallaccua@gmail.com";       // quem pode usar a função
const RESPONDER_PARA = "contatocrisdallaccua@gmail.com";  // onde caem as respostas
const MAXIMO_POR_CHAMADA = 250;
const ESPERA_ENTRE_ENVIOS = 200; // milissegundos, cerca de 5 por segundo

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const responde = (corpo: unknown, status = 200) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));
const escHTML = (t: string) => t.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const primeiroNome = (marca: string) => (marca.trim().split(/\s+/)[0] || marca).trim();
const troca = (texto: string, marca: string, html: boolean) => {
  const nome = html ? escHTML(primeiroNome(marca)) : primeiroNome(marca);
  const completo = html ? escHTML(marca) : marca;
  return texto.replace(/\{\{\s*nome\s*\}\}/gi, nome).replace(/\{\{\s*marca\s*\}\}/gi, completo);
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return responde({ erro: "Use POST." }, 405);

  // 1. Só você, logada, pode usar.
  const auth = req.headers.get("Authorization") || "";
  const url = Deno.env.get("SUPABASE_URL")!;
  let chavePublica = Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!chavePublica) {
    try { const k = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || "{}"); chavePublica = k.default || Object.values(k)[0] || ""; } catch { /* sem chave pública */ }
  }
  if (!auth.startsWith("Bearer ")) return responde({ erro: "Faça login no painel primeiro." }, 401);
  const banco = createClient(url, chavePublica, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
  const { data: quem, error: erroLogin } = await banco.auth.getUser(auth.slice(7));
  if (erroLogin || !quem?.user || String(quem.user.email || "").toLowerCase() !== MEU_EMAIL) {
    return responde({ erro: "Acesso recusado." }, 403);
  }

  const chaveResend = Deno.env.get("RESEND_API_KEY");
  if (!chaveResend) return responde({ erro: "Falta guardar a chave do Resend (RESEND_API_KEY) nos segredos da função." }, 500);
  const remetente = Deno.env.get("EMAIL_FROM") || "Cris Dall' Accua <onboarding@resend.dev>";

  // 2. O pedido: lista, assunto e HTML.
  let pedido: { destinatarios?: { email?: string; marca?: string }[]; assunto?: string; html?: string; pularMesmoAssunto?: boolean };
  try { pedido = await req.json(); } catch { return responde({ erro: "Pedido inválido." }, 400); }
  const assunto = String(pedido.assunto || "").trim();
  const html = String(pedido.html || "");
  if (!assunto || !html) return responde({ erro: "Falta o assunto ou o texto." }, 400);
  const lista = Array.isArray(pedido.destinatarios) ? pedido.destinatarios : [];

  // 3. No máximo 250 por chamada.
  if (lista.length > MAXIMO_POR_CHAMADA) return responde({ erro: `No máximo ${MAXIMO_POR_CHAMADA} por vez.` }, 400);

  // Nunca duas vezes o mesmo e-mail no mesmo disparo.
  const vistos = new Set<string>();
  const unicos: { email: string; marca: string }[] = [];
  for (const d of lista) {
    const email = String(d.email || "").trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || vistos.has(email)) continue;
    vistos.add(email);
    unicos.push({ email, marca: String(d.marca || "").trim() || email.split("@")[0] });
  }

  // 5. Pula quem pediu para sair. E, se pedido, quem já recebeu este assunto.
  const emails = unicos.map((d) => d.email);
  const pular = new Set<string>();
  if (emails.length) {
    const { data: fora } = await banco.from("email_optout").select("email").in("email", emails);
    (fora || []).forEach((r: { email: string }) => pular.add(String(r.email).toLowerCase()));
    if (pedido.pularMesmoAssunto !== false) {
      const { data: ja } = await banco.from("email_envios").select("email").eq("assunto", assunto).eq("status", "ok").in("email", emails);
      (ja || []).forEach((r: { email: string }) => pular.add(String(r.email).toLowerCase()));
    }
  }

  let enviados = 0, falhas = 0, pulados = lista.length - unicos.length, cotaAcabou = false, faltaram = 0;
  const resultados: { email: string; status: string; erro?: string }[] = [];

  for (let i = 0; i < unicos.length; i++) {
    const d = unicos[i];
    if (pular.has(d.email)) { pulados++; resultados.push({ email: d.email, status: "pulado" }); continue; }

    // 4. Troca {{nome}} e {{marca}}. 7 e 8: responder para você e o cabeçalho do SAIR.
    const corpo = {
      from: remetente,
      to: [d.email],
      subject: troca(assunto, d.marca, false),
      html: troca(html, d.marca, true),
      reply_to: RESPONDER_PARA,
      headers: { "List-Unsubscribe": `<mailto:${RESPONDER_PARA}?subject=SAIR>` },
    };

    let r: Response | null = null, dados: Record<string, unknown> = {};
    for (let tentativa = 0; tentativa < 2; tentativa++) {
      try {
        r = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: { Authorization: `Bearer ${chaveResend}`, "Content-Type": "application/json" },
          body: JSON.stringify(corpo),
        });
        dados = await r.json().catch(() => ({}));
      } catch (e) { r = null; dados = { message: String(e) }; }
      // rápido demais: espera um pouco e tenta de novo, uma vez
      if (r && r.status === 429 && dados.name === "rate_limit_exceeded" && tentativa === 0) { await espera(1200); continue; }
      break;
    }

    // 10. Cota do dia acabou: para na hora.
    const nomeErro = String(dados.name || "");
    if (nomeErro === "daily_quota_exceeded" || nomeErro === "monthly_quota_exceeded") {
      cotaAcabou = true;
      faltaram = unicos.slice(i).filter((x) => !pular.has(x.email)).length;
      break;
    }

    const ok = !!r && r.ok && !!dados.id;
    const erro = ok ? null : String(dados.message || dados.name || (r ? `Erro ${r.status}` : "Sem conexão com o Resend"));
    if (ok) enviados++; else falhas++;
    resultados.push({ email: d.email, status: ok ? "ok" : "erro", ...(erro ? { erro } : {}) });

    // 9. Uma linha por destinatário no registro, na hora.
    await banco.from("email_envios").insert({
      email: d.email, marca: d.marca, assunto, status: ok ? "ok" : "erro", erro, resend_id: ok ? String(dados.id) : null, via: "resend",
    });

    // Domínio ainda não verificado no Resend: ele só deixa mandar para você mesma. Para aqui.
    if (!ok && r && r.status === 403 && /domain|testing emails|own email/i.test(erro || "")) break;

    // 6. Ritmo seguro.
    if (i < unicos.length - 1) await espera(ESPERA_ENTRE_ENVIOS);
  }

  // 11. O resumo.
  return responde({ enviados, falhas, pulados, cotaAcabou, faltaram, resultados });
});
