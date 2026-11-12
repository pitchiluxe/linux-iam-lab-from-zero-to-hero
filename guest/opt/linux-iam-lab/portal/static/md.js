/* Tiny Markdown renderer for the Linux IAM Lab (offline, no dependencies).
   Supports: headings, paragraphs, **bold**, *italic*, `code`, [links](url), fenced code with a
   language tag, ordered/unordered lists (one nesting level), tables, blockquotes, hr. */
(function (global) {
  'use strict';
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  function inline(s) {
    const codes = [];
    s = s.replace(/`([^`]+)`/g, (_, c) => { codes.push(c); return '\u0000' + (codes.length - 1) + '\u0000'; });
    s = esc(s);
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/(^|[^*\w])\*([^*\s][^*]*)\*(?!\w)/g, '$1<em>$2</em>');
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, t, u) => {
      const safe = /^(https?:|#|\/)/.test(u) ? u : '#';
      const ext = /^https?:/.test(u) ? ' target="_blank" rel="noopener noreferrer"' : '';
      return `<a href="${safe}"${ext}>${t}</a>`;
    });
    s = s.replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${esc(codes[+i])}</code>`);
    return s;
  }

  const WHERE = {
    linux: ['linux', 'LINUX VM', 'type in the Linux terminal (student@iamlab01)'],
    bash: ['linux', 'LINUX VM', 'type in the Linux terminal (student@iamlab01)'],
    sh: ['linux', 'LINUX VM', 'type in the Linux terminal (student@iamlab01)'],
    powershell: ['windows', 'WINDOWS POWERSHELL', 'type on Windows, in PowerShell / Windows Terminal'],
    ps: ['windows', 'WINDOWS POWERSHELL', 'type on Windows, in PowerShell / Windows Terminal'],
    text: ['output', 'EXAMPLE OUTPUT', 'what you should roughly see'],
    output: ['output', 'EXAMPLE OUTPUT', 'what you should roughly see'],
    ini: ['file', 'FILE CONTENT', 'text inside a file'],
    conf: ['file', 'FILE CONTENT', 'text inside a file'],
  };

  function codeBlock(lang, lines) {
    const w = WHERE[lang] || ['file', (lang || 'TEXT').toUpperCase(), ''];
    const body = esc(lines.join('\n'));
    const runnable = w[0] === 'linux' || w[0] === 'windows';
    return `<div class="code code-${w[0]}"><div class="code-head"><span class="badge badge-${w[0]}" title="${w[2]}">${w[1]}</span>` +
      `<span class="code-tools">${runnable ? '<button class="mini explain" title="Ask the tutor to explain this before you run it">Explain</button>' : ''}` +
      `<button class="mini copy" title="Copy">Copy</button></span></div><pre><code>${body}</code></pre></div>`;
  }

  function table(rows) {
    const cells = (r) => r.replace(/^\||\|$/g, '').split('|').map((c) => inline(c.trim()));
    const head = cells(rows[0]);
    const body = rows.slice(2).map(cells);
    return '<div class="table-wrap"><table><thead><tr>' + head.map((h) => `<th>${h}</th>`).join('') +
      '</tr></thead><tbody>' + body.map((r) => '<tr>' + r.map((c) => `<td>${c}</td>`).join('') + '</tr>').join('') + '</tbody></table></div>';
  }

  function render(md) {
    const lines = (md || '').replace(/\r\n/g, '\n').split('\n');
    const out = [];
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      const fence = line.match(/^```\s*([\w-]*)/);
      if (fence) {
        const buf = [];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) buf.push(lines[i++]);
        i++;
        out.push(codeBlock(fence[1].toLowerCase(), buf));
        continue;
      }
      const h = line.match(/^(#{1,6})\s+(.*)$/);
      if (h) {
        const lvl = Math.min(6, h[1].length + 1);
        const id = h[2].toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
        out.push(`<h${lvl} id="h-${id}">${inline(h[2])}</h${lvl}>`);
        i++;
        continue;
      }
      if (/^\s*(---|\*\*\*)\s*$/.test(line)) { out.push('<hr>'); i++; continue; }
      if (/^\|.*\|\s*$/.test(line) && i + 1 < lines.length && /^\|?\s*:?-+/.test(lines[i + 1])) {
        const rows = [];
        while (i < lines.length && /^\|.*\|\s*$/.test(lines[i])) rows.push(lines[i++]);
        out.push(table(rows));
        continue;
      }
      if (/^>\s?/.test(line)) {
        const buf = [];
        while (i < lines.length && /^>\s?/.test(lines[i])) buf.push(lines[i++].replace(/^>\s?/, ''));
        let cls = 'note';
        const first = buf[0] || '';
        if (/^\*\*(warning|careful|danger)/i.test(first)) cls = 'warn';
        else if (/^\*\*(tip|why)/i.test(first)) cls = 'tip';
        else if (/^\*\*(windows)/i.test(first)) cls = 'win';
        out.push(`<blockquote class="callout ${cls}">${render(buf.join('\n'))}</blockquote>`);
        continue;
      }
      if (/^\s*([-*]|\d+\.)\s+/.test(line)) {
        const ordered = /^\s*\d+\./.test(line);
        const items = [];
        while (i < lines.length && (/^\s*([-*]|\d+\.)\s+/.test(lines[i]) || (/^\s{2,}\S/.test(lines[i]) && items.length))) {
          const l = lines[i];
          const m = l.match(/^(\s*)([-*]|\d+\.)\s+(.*)$/);
          if (m && m[1].length < 2) items.push({ text: m[3], sub: [] });
          else if (m) items[items.length - 1].sub.push(m[3]);
          else items[items.length - 1].text += ' ' + l.trim();
          i++;
        }
        const tag = ordered ? 'ol' : 'ul';
        out.push(`<${tag}>` + items.map((it) => `<li>${inline(it.text)}${it.sub.length ? '<ul>' + it.sub.map((s) => `<li>${inline(s)}</li>`).join('') + '</ul>' : ''}</li>`).join('') + `</${tag}>`);
        continue;
      }
      if (!line.trim()) { i++; continue; }
      const buf = [];
      while (i < lines.length && lines[i].trim() && !/^(```|#{1,6}\s|>|\s*([-*]|\d+\.)\s+|\|)/.test(lines[i])) buf.push(lines[i++]);
      if (buf.length) out.push(`<p>${inline(buf.join(' '))}</p>`);
      else i++;
    }
    return out.join('\n');
  }

  global.LabMarkdown = { render, inline, esc };
})(typeof window !== 'undefined' ? window : globalThis);
