// Página de roteiro: vários roteiros no mesmo link (usado por roteiro/index.html quando o JSON tem "roteiros").
// Vários roteiros no mesmo link: o JSON traz "roteiros": [ {...}, {...} ].
// Cada roteiro tem a sua decisão (aprovar ou ajustar) e vira uma resposta própria no painel.
window.renderMulti = function (p, ctx) {
  const { app, esc, lerRascunho, guardar, chave, id, B, AVISO_URL } = ctx;
  const R = p.roteiros;
  document.title = 'Roteiros ' + p.marca + ' · Cris Dall\' Accua';
  const rasc = lerRascunho();
  const coments = rasc.cenas || {};
  const decs = rasc.decisoes || {};
  const clima = c => c ? `<section class="card"><div><span class="rot">Mood board</span><h2>O clima do <em>vídeo</em></h2></div>
    ${c.texto ? `<p>${esc(c.texto)}</p>` : ''}
    <div class="clima">
      ${c.imagem ? `<figure><img src="${esc(c.imagem.src)}" alt="${esc(c.imagem.alt || '')}" loading="lazy" onerror="this.closest('figure').remove()">${c.imagem.legenda ? `<figcaption>${esc(c.imagem.legenda)}</figcaption>` : ''}</figure>` : ''}
      <div class="tons">${(c.itens || []).map(t => `<div class="tom"><i style="background:${/^#[0-9a-f]{3,8}$/i.test(t.cor || '') ? t.cor : 'var(--bloco)'}"></i><div><b>${esc(t.nome)}</b><span>${esc(t.texto || '')}</span></div></div>`).join('')}</div>
    </div></section>` : '';
  const cena = (c, chaveCena, num, rotulo) => `
      <li class="cena${coments[chaveCena] ? ' tem' : ''}" data-k="${chaveCena}">
        <div class="cab"><span class="num">${String(num).padStart(2,'0')}</span>${c.tempo ? `<span class="tempo">${esc(c.tempo)}</span>` : ''}</div>
        <p class="fala">“${esc(c.fala)}”</p>
        <div class="parte"><span class="rot">O que aparece</span><p>${esc(c.visual)}</p></div>
        ${c.tela ? `<div class="parte tela"><span class="rot">Texto na tela</span><div><span>${esc(c.tela)}</span></div></div>` : ''}
        <button class="comentar" type="button" aria-expanded="${coments[chaveCena] ? 'true' : 'false'}">${coments[chaveCena] ? 'Editar comentário' : 'Comentar esta cena'}</button>
        <div class="caixa${coments[chaveCena] ? ' aberta' : ''}"><textarea data-k="${chaveCena}" aria-label="Comentário sobre ${rotulo}, cena ${num}" placeholder="O que você gostaria de mudar nesta cena?">${esc(coments[chaveCena] || '')}</textarea></div>
      </li>`;
  const bloco = (r, k) => {
    const n = k + 1;
    return `
  <section class="roteiro" id="roteiro-${n}">
    <div class="sep"><span class="rot">Roteiro ${n} de ${R.length}</span><h2>${esc(r.titulo)}</h2>${r.objetivo ? `<p>${esc(r.objetivo)}</p>` : ''}${r.formato ? `<span class="rot">${esc(r.formato)}</span>` : ''}</div>
    <section class="card"><span class="rot">O gancho</span><p class="gancho">“${esc(r.gancho)}”</p></section>
    ${clima(r.clima)}
    <section class="card">
      <div><span class="rot">Roteiro ${n}</span><h2>Cena a <em>cena</em></h2></div>
      <ol class="cenas">${(r.cenas || []).map((c, i) => cena(c, n + '-' + (i + 1), i + 1, 'roteiro ' + n)).join('')}</ol>
    </section>
    ${(r.naoPodeFaltar || r.gravacao) ? `<section class="card">
      <span class="rot">Detalhes</span><h2>Gravação e <em>cuidados</em></h2>
      <div class="duas">
        <div><h3 style="margin-bottom:10px">O que não pode faltar</h3><ul class="lista">${(r.naoPodeFaltar || []).map(x => `<li>${esc(x)}</li>`).join('')}</ul></div>
        <div><h3 style="margin-bottom:10px">Como vai ser gravado</h3><ul class="lista">${(r.gravacao || []).map(x => `<li>${esc(x)}</li>`).join('')}</ul></div>
      </div>
    </section>` : ''}
  </section>`;
  };

  app.innerHTML = `
  <header class="hero${p.imagem ? ' com-foto' : ''}">
    <div class="hero-txt">
    <p class="rot">${esc(p.marca)} · ${esc(p.campanha)}</p>
    <h1>${esc(p.marca)} <em>&amp;</em> Cris · ${esc(p.titulo)}</h1>
    ${p.objetivo ? `<p class="obj">${esc(p.objetivo)}</p>` : ''}
    <div class="dados">
      <div><span class="rot">Formato</span><b>${esc(p.formato)}</b></div>
      <div><span class="rot">Creator</span><b>${esc(p.creator)}</b></div>
    </div>
    </div>
    ${p.imagem ? `<figure class="foto-prod"><img src="${esc(p.imagem.src)}" alt="${esc(p.imagem.alt || p.campanha)}" onerror="this.closest('figure').remove()"></figure>` : ''}
  </header>
  <p class="aviso">São ${R.length} roteiros neste link. Leia com calma. Para mudar alguma coisa, toque em <b>Comentar esta cena</b>. No final, escolha aprovar ou ajustar cada roteiro e envie uma resposta só.</p>
  <nav class="card indice" aria-label="Roteiros deste link">
    <div class="barra"><div><span class="rot">Neste link</span><h2>Os <em>roteiros</em></h2></div>
      <button class="btn" id="falas" type="button" aria-pressed="false">Ler só as falas</button></div>
    <ol>${R.map((r, k) => `<li><a href="#roteiro-${k + 1}"><span class="num">${String(k + 1).padStart(2, '0')}</span>${esc(r.titulo)}</a></li>`).join('')}</ol>
  </nav>
  ${R.map(bloco).join('')}
  <section class="card resp" id="resposta">
    <span class="rot">Sua resposta</span><h2>Aprovar ou <em>ajustar</em></h2>
    <div class="escolhas">${R.map((r, k) => `
      <fieldset class="escolha"><legend>Roteiro ${k + 1} · ${esc(r.titulo)}</legend>
        <label><input type="radio" name="d${k + 1}" value="aprovado"${decs[k + 1] === 'aprovado' ? ' checked' : ''}> Aprovar</label>
        <label><input type="radio" name="d${k + 1}" value="ajuste"${decs[k + 1] === 'ajuste' ? ' checked' : ''}> Pedir ajuste</label>
      </fieldset>`).join('')}</div>
    <p class="resumo" id="resumo"></p>
    <label>Algum comentário geral? (opcional)<textarea id="geral">${esc(rasc.geral || '')}</textarea></label>
    <label>Seu nome (opcional)<input id="nome" autocomplete="name" value="${esc(rasc.nome || '')}"></label>
    <div class="acoes"><button class="btn cheio" id="enviar" type="button">Enviar resposta</button></div>
    <p class="status" id="status" role="status"></p>
  </section>`;

  const estado = () => {
    const cenas = {}; const decisoes = {};
    app.querySelectorAll('.cena textarea').forEach(t => { if (t.value.trim()) cenas[t.dataset.k] = t.value.trim(); });
    R.forEach((r, k) => { const m = app.querySelector(`input[name="d${k + 1}"]:checked`); if (m) decisoes[k + 1] = m.value; });
    return { cenas, decisoes, geral: document.getElementById('geral').value, nome: document.getElementById('nome').value };
  };
  const atualizar = () => {
    const s = estado(); guardar(s);
    app.querySelectorAll('.cena').forEach(li => li.classList.toggle('tem', !!s.cenas[li.dataset.k]));
    const ks = Object.keys(s.cenas);
    document.getElementById('resumo').textContent = ks.length
      ? 'Você comentou: ' + ks.map(x => { const [a, b] = x.split('-'); return 'roteiro ' + a + ', cena ' + b; }).join('; ') + '.'
      : 'Nenhuma cena comentada até agora.';
  };
  app.addEventListener('input', atualizar);
  app.addEventListener('change', atualizar);
  atualizar();

  app.querySelectorAll('.comentar').forEach(b => b.addEventListener('click', () => {
    const caixa = b.nextElementSibling; const abre = !caixa.classList.contains('aberta');
    caixa.classList.toggle('aberta', abre); b.setAttribute('aria-expanded', abre);
    if (abre) caixa.querySelector('textarea').focus();
  }));
  const bf = document.getElementById('falas');
  bf.addEventListener('click', () => {
    const on = document.body.classList.toggle('so-falas');
    bf.setAttribute('aria-pressed', on); bf.textContent = on ? 'Ver roteiros completos' : 'Ler só as falas';
  });

  const enviados = new Set();
  document.getElementById('enviar').addEventListener('click', async () => {
    const s = estado(); const st = document.getElementById('status');
    const falta = R.map((r, k) => k + 1).filter(n => !s.decisoes[n]);
    if (falta.length) { st.textContent = 'Escolha aprovar ou pedir ajuste ' + (falta.length === 1 ? 'no roteiro ' + falta[0] : 'nos roteiros ' + falta.join(' e ')) + '.'; return; }
    const semMotivo = R.map((r, k) => k + 1).filter(n => s.decisoes[n] === 'ajuste'
      && !Object.keys(s.cenas).some(x => x.split('-')[0] === String(n)) && !s.geral.trim());
    if (semMotivo.length) { st.textContent = 'Conte o que você quer ajustar no roteiro ' + semMotivo.join(' e ') + ': comente uma cena ou escreva no comentário geral.'; return; }
    if (!B) { st.textContent = 'O envio não está disponível agora. Responda pela mensagem em que você recebeu este link.'; return; }
    const bt = document.getElementById('enviar'); bt.disabled = true;
    st.textContent = 'Enviando…';
    try {
      for (let k = 0; k < R.length; k++) {
        const n = k + 1; if (enviados.has(n)) continue;
        const corpo = { roteiro: id, marca: p.marca, titulo: p.campanha + ' · Roteiro ' + n + ': ' + R[k].titulo, decisao: s.decisoes[n],
          nome: s.nome.trim() || null, geral: s.geral.trim() || null,
          cenas: Object.entries(s.cenas).filter(([x]) => x.split('-')[0] === String(n))
            .map(([x, comentario]) => ({ cena: Number(x.split('-')[1]), comentario })) };
        const resp = await fetch(B.url + '/rest/v1/roteiro_respostas', { method: 'POST',
          headers: { apikey: B.chave, 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify(corpo) });
        if (!resp.ok) throw new Error('falha ' + resp.status);
        enviados.add(n);
        if (AVISO_URL.startsWith('https://')) { try { fetch(AVISO_URL, { method: 'POST', mode: 'no-cors', keepalive: true, headers: { 'Content-Type': 'text/plain;charset=utf-8' }, body: JSON.stringify(corpo) }); } catch (e) {} }
      }
      try { localStorage.removeItem(chave); } catch (e) {}
      const ap = R.map((r, k) => k + 1).filter(n => s.decisoes[n] === 'aprovado');
      const aj = R.map((r, k) => k + 1).filter(n => s.decisoes[n] === 'ajuste');
      const lista = a => (a.length === 1 ? 'o roteiro ' : 'os roteiros ') + a.join(' e ');
      app.innerHTML = `<section class="card feito"><span class="rot">Resposta enviada</span>
        <h2>${!aj.length ? 'Roteiros <em>aprovados</em>. Obrigada!' : !ap.length ? 'Recebi os <em>ajustes</em>. Obrigada!' : 'Recebi sua <em>resposta</em>. Obrigada!'}</h2>
        <p>${!aj.length ? 'Agora eu sigo para a gravação e envio os vídeos para validação antes de publicar.'
          : !ap.length ? 'Vou ajustar os roteiros e te mando a nova versão neste mesmo link.'
          : 'Sigo para a gravação com ' + lista(ap) + ' e vou ajustar ' + lista(aj) + '. A nova versão chega neste mesmo link.'}</p></section>`;
      scrollTo(0, 0);
    } catch (e) {
      bt.disabled = false;
      st.textContent = 'Não consegui enviar agora. Tente de novo em instantes ou responda pela mensagem em que você recebeu este link.';
    }
  });
};
