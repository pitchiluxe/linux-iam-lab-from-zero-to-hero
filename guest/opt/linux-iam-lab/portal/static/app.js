/* Linux IAM Lab portal - single page app, no dependencies, works offline. */
(function () {
  'use strict';
  const MD = window.LabMarkdown;
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));
  const S = { course: [], ref: [], progress: { exercises: {}, lessons: {} }, ex: null, mode: 'chat', history: [], termUrl: '', busy: false };

  // ------------------------------------------------------------------ api
  async function api(path, opts = {}) {
    const o = Object.assign({ headers: {} }, opts);
    if (o.method === 'POST') o.headers['X-Lab'] = '1';
    const r = await fetch(path, o);
    if (r.status === 401) { location.reload(); throw new Error('not signed in'); }
    return r.json();
  }
  function toast(msg) {
    const t = $('#toast'); t.textContent = msg; t.hidden = false;
    clearTimeout(toast.t); toast.t = setTimeout(() => (t.hidden = true), 2600);
  }
  const allExercises = () => S.course.flatMap((m) => m.exercises);
  const exStatus = (id) => (S.progress.exercises[id] || {}).status || 'not_started';
  const findEx = (id) => allExercises().find((e) => e.id === id);
  const modOf = (id) => S.course.find((m) => m.exercises.some((e) => e.id === id));

  // ------------------------------------------------------------------ chrome
  function renderProgress() {
    const all = allExercises();
    const done = all.filter((e) => exStatus(e.id) === 'passed').length;
    $('#progress-fill').style.width = all.length ? (100 * done / all.length) + '%' : '0';
    $('#progress-text').textContent = `${done} / ${all.length} passed`;
  }
  function renderSidebar() {
    const route = location.hash || '#/';
    let h = `<a class="nav-link ${route === '#/' ? 'active' : ''}" href="#/">Start here</a>`;
    h += `<h3>Modules</h3>`;
    for (const m of S.course) {
      const done = m.exercises.filter((e) => exStatus(e.id) === 'passed').length;
      const active = route === `#/module/${m.id}` ? 'active' : '';
      h += `<a class="nav-link nav-mod ${active}" href="#/module/${m.id}"><span class="num">${String(m.number).padStart(2, '0')}</span>${MD.esc(m.title)}<span class="ring">${done}/${m.exercises.length}</span></a>`;
      const open = route.includes(m.id) || (S.ex && S.ex.module === m.id);
      if (open) {
        for (const e of m.exercises) {
          h += `<a class="nav-link nav-ex ${route === '#/ex/' + e.id ? 'active' : ''}" href="#/ex/${e.id}"><span class="mark ${exStatus(e.id)}"></span>${MD.esc(e.title)}</a>`;
        }
      }
    }
    h += `<h3>Library</h3>
      <a class="nav-link ${route.startsWith('#/reference') ? 'active' : ''}" href="#/reference">Reference library</a>
      <a class="nav-link ${route === '#/progress' ? 'active' : ''}" href="#/progress">Progress &amp; lab tools</a>`;
    $('#sidebar').innerHTML = h;
  }
  async function refreshStatus() {
    try {
      const s = await api('/api/status');
      const svc = s.services || {};
      const needed = ['ssh', 'sssd', 'slapd', 'lab-terminal'];
      const bad = needed.filter((k) => svc[k] !== 'active');
      $('#st-vm').className = 'dot ' + (bad.length ? 'warn' : 'ok');
      $('#st-vm').title = bad.length ? 'Not active: ' + bad.join(', ') : 'Linux VM services are running';
      const t = s.tutor || {};
      $('#st-tutor').className = 'dot ' + (t.online && t.modelReady ? 'ok' : t.online ? 'warn' : 'bad');
      $('#st-tutor').title = t.online ? (t.modelReady ? `Tutor ready (${t.model})` : `Ollama is running but model ${t.model} is missing (run: sudo lab tutor-pull)`) : 'Tutor offline - lessons and checks still work';
      S.status = s;
    } catch (e) { $('#st-vm').className = 'dot bad'; }
  }

  // ------------------------------------------------------------------ pages
  function page(html) {
    const m = $('#main'); m.innerHTML = `<div class="content">${html}</div>`; m.scrollTop = 0; wireCode(m);
  }
  function wireCode(root) {
    $$('.code', root).forEach((c) => {
      const code = $('code', c).textContent;
      const copy = $('.copy', c); if (copy) copy.onclick = () => { navigator.clipboard.writeText(code).then(() => toast('Copied')); };
      const ex = $('.explain', c); if (ex) ex.onclick = () => askTutor('explain', 'Explain this before I run it:\n' + code);
    });
  }

  function home() {
    S.ex = null;
    const all = allExercises();
    const next = all.find((e) => exStatus(e.id) !== 'passed');
    let h = `<h1>Linux IAM: Zero to Hero</h1>
      <p class="lead">Hands-on Linux for Identity and Access Management analysts and engineers. Every exercise is a realistic ticket that you solve with real commands in your own Linux VM. The lab then tests the result <em>as the affected users</em> - can they read the file, log in, run the command?</p>`;
    if (next) h += `<p><a class="btn primary" href="#/ex/${next.id}">${exStatus(next.id) === 'in_progress' ? 'Continue' : 'Start'}: ${MD.esc(next.title)} →</a></p>`;
    h += `<h2>Where am I typing?</h2>
      <div class="where-grid">
        <div class="where-card linux"><b><span class="badge badge-linux">LINUX VM</span> Linux terminal</b>
          The <b>Lab Terminal</b> window on this Linux desktop (also: the panel on the right, or <code>ssh linux-iam-lab</code> from Windows Terminal). The prompt looks like <code>student@iamlab01:~$</code>. Almost every command in this course goes here.</div>
        <div class="where-card windows"><b><span class="badge badge-windows">WINDOWS POWERSHELL</span> Your Windows PC</b>
          Outside this VM window. The prompt looks like <code>PS C:\\Users\\you&gt;</code>. Only used for the Start / Stop / Reset desktop shortcuts and to SSH in. Linux commands do not work there.</div>
      </div>
      <p>Every command block in the course is labelled the same way. Grey <span class="badge badge-output">EXAMPLE OUTPUT</span> blocks show what you should roughly see; do not type them.</p>
      <h2>How each exercise works</h2>
      <ol><li><b>Read the ticket.</b> It is the request a real IAM team would receive.</li>
      <li><b>Learn the commands</b> in "Concepts and commands" - every flag is explained with sample output.</li>
      <li><b>Do the task</b> in the Linux terminal. Stuck? Open hints one at a time, or ask the tutor to nudge you.</li>
      <li><b>Check my work</b> runs real tests in the VM (allowed actions must work, denied ones must fail).</li>
      <li><b>Retry exercise</b> puts just that scenario back to the start. The Windows <b>Reset Linux IAM Lab</b> shortcut restores the whole VM.</li></ol>
      <h2>Course map</h2><div class="card-grid">`;
    for (const m of S.course) {
      const done = m.exercises.filter((e) => exStatus(e.id) === 'passed').length;
      h += `<a class="card" href="#/module/${m.id}"><div class="num">MODULE ${m.number}</div><h4>${MD.esc(m.title)}</h4><p>${MD.esc(m.summary)}</p>
        <div class="cbar"><div style="width:${m.exercises.length ? 100 * done / m.exercises.length : 0}%"></div></div></a>`;
    }
    h += `</div>`;
    page(h);
  }

  function modulePage(id) {
    const m = S.course.find((x) => x.id === id);
    if (!m) return page('<h1>Not found</h1>');
    S.ex = null;
    let h = `<div class="meta"><span class="tag">Module ${m.number}</span><span class="tag">${m.exercises.length} exercises</span></div>
      <h1>${MD.esc(m.title)}</h1><p class="lead">${MD.esc(m.summary)}</p>${MD.render(m.lesson)}
      <h2>Exercises</h2><div class="card-grid">`;
    for (const e of m.exercises) {
      const st = exStatus(e.id);
      h += `<a class="card" href="#/ex/${e.id}"><div class="num">${e.id}</div><h4>${MD.esc(e.title)}</h4>
        <p>~${e.minutes} min · <span class="tag ${st}">${st.replace('_', ' ')}</span></p></a>`;
    }
    h += '</div>';
    page(h);
    api(`/api/lesson/${m.id}`, { method: 'POST' }).catch(() => {});
  }

  function exercisePage(id) {
    const e = findEx(id);
    if (!e) return page('<h1>Exercise not found</h1>');
    S.ex = e;
    const st = exStatus(id);
    const used = (S.progress.exercises[id] || {}).hintsUsed || 0;
    const m = modOf(id);
    let h = `<div class="meta"><span class="tag">Module ${m.number}: ${MD.esc(m.title)}</span><span class="tag">${e.id}</span><span class="tag">~${e.minutes} min</span><span class="tag ${st}" id="ex-status">${st.replace('_', ' ')}</span></div>
      <h1>${MD.esc(e.title)}</h1>`;
    if (e.prereqs.length) h += `<p class="lead">Builds on: ${e.prereqs.map((p) => `<a href="#/ex/${p}">${p}</a>`).join(', ')} (each exercise prepares its own data, so you can still do this one first).</p>`;
    for (const s of e.sections) h += `<h2 id="sec-${s.key}">${MD.esc(s.title)}</h2>${MD.render(s.md)}`;
    if (e.id === 'm09-capstone') {
      h += `<h2>Capstone stages</h2><div class="actions"><button class="btn" data-cap="status">Show stage status</button><button class="btn" data-cap="next">Advance to next stage</button><button class="btn" data-cap="evidence">Generate evidence report</button></div><div id="cap-out"></div>`;
    }
    if (e.start) h += `<div class="actions"><button class="btn primary" id="start-scenario">Start scenario</button><span>This exercise changes the VM on purpose. Start it when you are ready.</span></div>`;
    h += `<div class="actions">
        ${e.hasCheck ? '<button class="btn primary" id="check">Check my work</button>' : ''}
        <button class="btn" id="nudge">Ask tutor for a nudge</button>
        <button class="btn danger" id="retry" title="Put only this exercise back to its starting state">Retry exercise</button>
        <span class="tag">or in Linux: <code>lab check ${e.id}</code></span>
      </div><div id="result"></div>
      <h2>Hints</h2><p>Open them one at a time - each one tells you a bit more.</p><div id="hints"></div>
      ${e.hints.length ? `<button class="btn" id="more-hint">Show hint ${Math.min(used + 1, e.hints.length)} of ${e.hints.length}</button>` : ''}
      <h2>Walkthrough</h2>
      <details class="walk" id="walk"><summary>${st === 'passed' ? 'Review the full walkthrough' : 'I have tried - show the full walkthrough'}</summary>${MD.render(e.walkthrough)}</details>`;
    page(h);
    let shown = 0;
    const showHint = (n) => {
      for (; shown < n && shown < e.hints.length; shown++) {
        $('#hints').insertAdjacentHTML('beforeend', `<div class="hintbox"><h4>Hint ${shown + 1}</h4>${MD.render(e.hints[shown])}</div>`);
      }
      wireCode($('#hints'));
      const b = $('#more-hint');
      if (b) { if (shown >= e.hints.length) b.remove(); else b.textContent = `Show hint ${shown + 1} of ${e.hints.length}`; }
    };
    showHint(used);
    if ($('#more-hint')) $('#more-hint').onclick = () => { showHint(shown + 1); api(`/api/hint/${e.id}/${shown}`, { method: 'POST' }).catch(() => {}); };
    if ($('#check')) $('#check').onclick = () => runCheck(e.id);
    $('#retry').onclick = () => retry(e.id);
    if ($('#start-scenario')) $('#start-scenario').onclick = () => retry(e.id, true);
    $('#nudge').onclick = () => askTutor('nudge', 'I am stuck on this exercise. Give me a nudge.');
    $$('[data-cap]').forEach((b) => (b.onclick = () => capstone(b.dataset.cap)));
  }

  function resultHtml(out, passed) {
    const lines = MD.esc(out || '').split('\n').map((l) => {
      const c = /^PASS/.test(l) ? 'pass' : /^FAIL/.test(l) ? 'fail' : /^HINT/.test(l) ? 'hint' : /^INFO/.test(l) ? 'info' : /^RESULT/.test(l) ? 'res' : '';
      return c ? `<span class="${c}">${l}</span>` : l;
    }).join('\n');
    return `<div class="result ${passed ? 'passed' : 'failed'}">${lines}</div>`;
  }
  async function runCheck(id) {
    const b = $('#check'); b.disabled = true; b.textContent = 'Checking… (testing access as the affected users)';
    try {
      const r = await api(`/api/check/${id}`, { method: 'POST' });
      if (!r.ok) { $('#result').innerHTML = resultHtml('FAIL: ' + (r.error || 'check failed to run'), false); return; }
      $('#result').innerHTML = resultHtml(r.output, r.passed);
      S.lastCheck = r.output;
      await loadProgress();
      const st = exStatus(id); const t = $('#ex-status'); if (t) { t.className = 'tag ' + st; t.textContent = st.replace('_', ' '); }
      toast(r.passed ? 'Passed - nice work!' : 'Not yet - read the FAIL lines');
    } finally { b.disabled = false; b.textContent = 'Check my work'; }
  }
  async function retry(id, starting) {
    if (!starting && !confirm(`Retry ${id}?\n\nThis puts ONLY this exercise's users, files and settings back to their starting state. Other exercises and your notes are kept. Your earlier pass is remembered.`)) return;
    const b = $('#retry'); b.disabled = true; b.textContent = 'Resetting…';
    try {
      const r = await api(`/api/reset/${id}`, { method: 'POST' });
      $('#result').innerHTML = resultHtml((r.output || '') + (r.ok ? '\nRESULT: exercise reset - ready to retry' : '\nFAIL: reset failed'), r.ok);
      await loadProgress();
    } finally { b.disabled = false; b.textContent = 'Retry exercise'; }
  }
  async function capstone(action) {
    $('#cap-out').innerHTML = '<div class="result">Working…</div>';
    const r = await api(`/api/capstone/${action}`, { method: 'POST' });
    $('#cap-out').innerHTML = resultHtml(r.output || r.error || '', r.ok);
  }

  function referencePage(docId, q) {
    S.ex = null;
    const doc = S.ref.find((d) => d.id === docId) || S.ref[0];
    let h = `<h1>Reference library</h1><p class="lead">Also saved on Windows as offline files in <code>Documents\\LinuxIAMLab\\Reference</code>.</p>
      <input id="ref-filter" type="search" placeholder="Filter this page (e.g. chmod, UID, Ctrl+R)" value="${MD.esc(q || '')}" style="width:100%;padding:8px 12px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--text);font:inherit">
      <div class="ref-tabs">${S.ref.map((d) => `<a class="btn ${d.id === doc.id ? 'primary' : ''}" href="#/reference/${d.id}">${MD.esc(d.title)}</a>`).join('')}</div>
      <div id="ref-body"></div>`;
    page(h);
    const draw = () => {
      const f = $('#ref-filter').value.trim().toLowerCase();
      let md = doc.md;
      if (f) {
        const parts = md.split(/\n(?=### )/);
        md = parts.filter((p, i) => i === 0 ? false : p.toLowerCase().includes(f)).join('\n') || `_No entries match "${f}" on this page. Try the search box at the top to search everything._`;
      }
      $('#ref-body').innerHTML = MD.render(md);
      wireCode($('#ref-body'));
    };
    $('#ref-filter').oninput = draw;
    draw();
  }

  async function progressPage() {
    S.ex = null;
    let h = `<h1>Progress &amp; lab tools</h1><h2>Your progress</h2><div class="table-wrap"><table><thead><tr><th>Module</th><th>Passed</th><th>Exercises</th></tr></thead><tbody>`;
    for (const m of S.course) {
      const done = m.exercises.filter((e) => exStatus(e.id) === 'passed');
      h += `<tr><td>${m.number}. ${MD.esc(m.title)}</td><td>${done.length}/${m.exercises.length}</td><td>${m.exercises.map((e) => `<a href="#/ex/${e.id}" title="${MD.esc(e.title)}">${exStatus(e.id) === 'passed' ? '✔' : '○'} ${e.id}</a>`).join('<br>')}</td></tr>`;
    }
    h += `</tbody></table></div>
      <p><a class="btn" href="/api/progress/export">Download progress (JSON)</a> · Full export of your files: run <b>Reset Linux IAM Lab</b> (it exports first) or <code>Export-LinuxIAMLabWork.ps1</code> on Windows.</p>
      <h2>Break-glass recovery</h2>
      <p>Locked yourself out while practising? In real life you would use the server console or a second admin. Here these buttons run a fixed, logged recovery as root. Use them only when a lesson tells you to, or when you are stuck.</p>
      <div class="actions" style="position:static">
        <button class="btn" data-rescue="sudoers">Fix broken sudo policy</button>
        <button class="btn" data-rescue="sshd">Fix broken SSH server config</button>
        <button class="btn" data-rescue="faillock">Unlock student (faillock)</button>
        <button class="btn" data-rescue="sssd">Repair directory / SSSD</button>
        <button class="btn" data-rescue="terminal">Restart web terminal</button>
      </div><div id="rescue-out"></div>
      <h2>Reset scope</h2>
      <ul><li><b>Retry exercise</b> (button on each exercise, or <code>lab reset &lt;id&gt;</code>): only that exercise's users, files and settings. Progress is kept.</li>
      <li><b>Reset Linux IAM Lab</b> (Windows desktop shortcut): restores the whole VM to the baseline saved at install. Your files in the VM are cleared after being exported to <code>Documents\\LinuxIAMLab\\Exports</code>; checkmarks are restored unless you choose otherwise.</li></ul>
      <h2>Lab status</h2><div id="svc"></div>`;
    page(h);
    $$('[data-rescue]').forEach((b) => (b.onclick = async () => {
      if (!confirm(`Run break-glass recovery: ${b.dataset.rescue}?`)) return;
      b.disabled = true;
      const r = await api(`/api/rescue/${b.dataset.rescue}`, { method: 'POST' });
      $('#rescue-out').innerHTML = resultHtml(r.output || r.error, r.ok);
      b.disabled = false;
    }));
    await refreshStatus();
    const s = S.status || {}; const svc = s.services || {};
    $('#svc').innerHTML = `<div class="kv">${Object.entries(svc).map(([k, v]) => `<span>${k}</span><span class="tag ${v === 'active' ? 'passed' : ''}">${v}</span>`).join('')}
      <span>Tutor model</span><span>${MD.esc((s.tutor || {}).model || '')} ${(s.tutor || {}).modelReady ? '(ready)' : '(not ready)'}</span>
      <span>SSH from Windows</span><span><code>ssh linux-iam-lab</code> (127.0.0.1 port ${MD.esc((s.settings || {}).sshPort || '')})</span>
      <span>VM host key</span><span><code>${MD.esc((s.settings || {}).fingerprint || '')}</code></span></div>`;
  }

  // ------------------------------------------------------------------ search
  function buildIndex() {
    const idx = [];
    for (const m of S.course) {
      idx.push({ t: `Module ${m.number}: ${m.title}`, s: m.summary + ' ' + m.lesson, href: `#/module/${m.id}`, k: 'Lesson' });
      for (const e of m.exercises) idx.push({ t: e.title, s: e.sections.map((x) => x.md).join(' '), href: `#/ex/${e.id}`, k: 'Exercise ' + e.id });
    }
    for (const d of S.ref) {
      for (const part of d.md.split(/\n(?=### )/)) {
        const m = part.match(/^### (.+)/);
        if (m) idx.push({ t: m[1], s: part, href: `#/reference/${d.id}?q=${encodeURIComponent(m[1].split(/[ (]/)[0])}`, k: d.title });
      }
    }
    S.index = idx;
  }
  function search(q) {
    const box = $('#search-results');
    q = q.trim().toLowerCase();
    if (q.length < 2) { box.hidden = true; return; }
    const terms = q.split(/\s+/);
    const hits = S.index.map((it) => {
      const t = it.t.toLowerCase(); const s = it.s.toLowerCase();
      let score = 0;
      for (const w of terms) { if (t.includes(w)) score += 5; if (s.includes(w)) score += 1; else if (!t.includes(w)) return null; }
      return score ? { it, score } : null;
    }).filter(Boolean).sort((a, b) => b.score - a.score).slice(0, 14);
    box.innerHTML = hits.length ? hits.map((h, i) => `<a href="${h.it.href}" class="${i === 0 ? 'sel' : ''}">${MD.esc(h.it.t)}<small>${MD.esc(h.it.k)}</small></a>`).join('') : '<a>No results</a>';
    box.hidden = false;
  }

  // ------------------------------------------------------------------ tutor
  function addMsg(role, html) {
    const d = document.createElement('div'); d.className = 'msg ' + role; d.innerHTML = html;
    $('#chat').appendChild(d); $('#chat').scrollTop = $('#chat').scrollHeight; return d;
  }
  function setMode(mode) {
    S.mode = mode; $$('.chip').forEach((c) => c.classList.toggle('active', c.dataset.mode === mode));
    const ph = { chat: 'Ask about a command, an error, or the exercise…', explain: 'Paste the command you want explained before running it…', error: 'What were you trying to do? Paste the error below in "Share terminal output".', nudge: 'Tell the tutor where you are stuck…', quiz: 'Type "start" or answer the last question…' };
    $('#question').placeholder = ph[mode];
  }
  function openDock(tab) {
    document.body.classList.remove('dock-hidden');
    $$('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === tab));
    $('#pane-terminal').hidden = tab !== 'terminal'; $('#pane-tutor').hidden = tab !== 'tutor';
    if (tab === 'terminal') ensureTerminal();
  }
  function askTutor(mode, text) { openDock('tutor'); setMode(mode); $('#question').value = text; send(); }
  async function send() {
    if (S.busy) return;
    const q = $('#question').value.trim(); const shared = $('#shared').value;
    if (!q && !shared.trim()) return;
    S.busy = true; $('#ask-btn').disabled = true;
    addMsg('user', MD.render(q || '(shared terminal output)'));
    const out = addMsg('assistant', '<em>Thinking… The tutor runs on the CPU of the lab VM: expect 1-4 minutes per answer on a typical laptop (faster with more CPU). The text appears as it is written; lessons, hints and checks keep working meanwhile.</em>');
    let text = '';
    try {
      const r = await fetch('/api/tutor', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Lab': '1' },
        body: JSON.stringify({ mode: S.mode, message: q, shared, exerciseId: S.ex ? S.ex.id : '', history: S.history.slice(-6) }) });
      const reader = r.body.getReader(); const dec = new TextDecoder(); let buf = '';
      for (;;) {
        const { done, value } = await reader.read(); if (done) break;
        buf += dec.decode(value, { stream: true });
        let nl;
        while ((nl = buf.indexOf('\n')) >= 0) {
          const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
          if (!line.trim()) continue;
          const ev = JSON.parse(line);
          if (ev.redacted) addMsg('system', `${ev.redacted} secret-looking item(s) were removed before the tutor saw your message.`);
          if (ev.t) { text += ev.t; out.innerHTML = MD.render(text); wireCode(out); $('#chat').scrollTop = $('#chat').scrollHeight; }
          if (ev.error) out.innerHTML = `<strong>Tutor unavailable.</strong> ${MD.esc(ev.error)}`;
        }
      }
      if (text) { S.history.push({ role: 'user', content: q }, { role: 'assistant', content: text }); }
      $('#question').value = ''; $('#shared').value = '';
    } catch (e) {
      out.innerHTML = '<strong>Tutor unavailable.</strong> The written lessons, hints and checks still work.';
    } finally { S.busy = false; $('#ask-btn').disabled = false; }
  }
  async function ensureTerminal() {
    if (S.termUrl) return;
    const r = await api('/api/terminal'); S.termUrl = r.url;
    $('#terminal').src = r.url; $('#term-pop').href = r.url; $('#term-pop').target = '_blank';
  }

  // ------------------------------------------------------------------ router / boot
  async function loadProgress() { const r = await api('/api/progress'); if (r.progress) S.progress = r.progress; renderProgress(); renderSidebar(); }
  function route() {
    const h = location.hash || '#/';
    const [path, qs] = h.slice(1).split('?');
    const q = new URLSearchParams(qs || '').get('q');
    const parts = path.split('/').filter(Boolean);
    $('#search-results').hidden = true;
    if (!parts.length) home();
    else if (parts[0] === 'module') modulePage(parts[1]);
    else if (parts[0] === 'ex') exercisePage(parts[1]);
    else if (parts[0] === 'reference') referencePage(parts[1], q);
    else if (parts[0] === 'progress') progressPage();
    else home();
    renderSidebar();
  }
  async function boot() {
    const theme = (() => { try { return localStorage.getItem('lab-theme'); } catch (e) { return null; } })();
    if (theme) document.documentElement.dataset.theme = theme;
    $('#theme').onclick = () => {
      const cur = document.documentElement.dataset.theme || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const nxt = cur === 'dark' ? 'light' : 'dark'; document.documentElement.dataset.theme = nxt;
      try { localStorage.setItem('lab-theme', nxt); } catch (e) { /* ignore */ }
    };
    $('#toggle-dock').onclick = () => { document.body.classList.toggle('dock-hidden'); if (!document.body.classList.contains('dock-hidden')) ensureTerminal(); };
    $$('.tab').forEach((t) => (t.onclick = () => openDock(t.dataset.tab)));
    $$('.chip').forEach((c) => (c.onclick = () => setMode(c.dataset.mode)));
    $('#ask').onsubmit = (ev) => { ev.preventDefault(); send(); };
    $('#question').onkeydown = (ev) => { if (ev.key === 'Enter' && !ev.shiftKey) { ev.preventDefault(); send(); } };
    const sb = $('#search');
    sb.oninput = () => search(sb.value);
    sb.onkeydown = (ev) => { if (ev.key === 'Enter') { const a = $('#search-results a.sel'); if (a && a.href) { location.hash = a.getAttribute('href'); sb.blur(); } } if (ev.key === 'Escape') { $('#search-results').hidden = true; sb.blur(); } };
    document.addEventListener('keydown', (ev) => { if (ev.key === '/' && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA') { ev.preventDefault(); sb.focus(); } });
    document.addEventListener('click', (ev) => { if (!ev.target.closest('.search-wrap')) $('#search-results').hidden = true; });
    $('#term-pop').onclick = (ev) => { if (!S.termUrl) ev.preventDefault(); };
    addMsg('system', 'Hi! I am your Linux IAM tutor. Pick a mode above. I explain, quiz and nudge - I never run commands.');
    const [c, r] = await Promise.all([api('/api/course'), api('/api/reference')]);
    S.course = c.modules; S.ref = r.docs; buildIndex();
    await loadProgress();
    window.addEventListener('hashchange', route);
    route();
    ensureTerminal();
    refreshStatus(); setInterval(refreshStatus, 30000);
  }
  boot().catch((e) => { $('#main').innerHTML = `<div class="content"><h1>Portal error</h1><p>${MD.esc(String(e))}</p></div>`; });
})();
