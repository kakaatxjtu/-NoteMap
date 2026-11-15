'use strict';

const $ = (s) => document.querySelector(s);

let currentId = null;
let currentTags = [];
let activeTag = null;
let previewTimer = null;
let saveTimer = null;
let dirty = false;

/* ---------- 基础请求 ---------- */
async function getJSON(path) {
  const r = await fetch(path, { headers: { 'Accept': 'application/json' } });
  return r.json();
}

async function postJSON(path, data) {
  const body = new URLSearchParams();
  for (const k in data) body.append(k, data[k]);
  const r = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString()
  });
  return r.json();
}

function toast(text) {
  const t = $('#toast');
  t.textContent = text;
  t.classList.remove('hidden');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.add('hidden'), 1600);
}

function setStatus(text) { $('#status').textContent = text; }

/* ---------- 文档树 ---------- */
async function loadTree() {
  const data = await getJSON('/api/tree');
  renderTree(data.folders, data.notes);
  renderTags(data.notes);
  $('#tree-count').textContent = data.notes.length + ' 篇';
  return data;
}

function renderTree(folders, notes) {
  const root = $('#tree');
  root.innerHTML = '';

  const byParent = {};
  folders.forEach(f => {
    const p = f.parent || '';
    (byParent[p] = byParent[p] || []).push(f);
  });
  const notesByFolder = {};
  notes.forEach(n => {
    const f = n.folder || '';
    (notesByFolder[f] = notesByFolder[f] || []).push(n);
  });

  const rows = [];
  const walk = (parentId, depth) => {
    (byParent[parentId] || []).forEach(f => {
      rows.push({ kind: 'folder', depth, id: f.id, name: f.name });
      walk(f.id, depth + 1);
    });
    (notesByFolder[parentId] || []).forEach(n => {
      rows.push({ kind: 'note', depth, id: n.id, name: n.title, tags: n.tags });
    });
  };
  walk('', 0);

  rows.forEach(r => {
    const el = document.createElement('div');
    el.className = 'node' + (r.kind === 'folder' ? ' folder-row' : '') + (r.id === currentId ? ' active' : '');
    el.style.paddingLeft = (16 + r.depth * 14) + 'px';
    const ico = document.createElement('span');
    ico.className = 'ico';
    ico.textContent = r.kind === 'folder' ? '▸' : '·';
    const t = document.createElement('span');
    t.className = 't';
    t.textContent = r.name;
    el.appendChild(ico);
    el.appendChild(t);

    const del = document.createElement('span');
    del.className = 'del';
    del.textContent = '×';
    del.title = r.kind === 'folder' ? '删除文件夹' : '删除笔记';
    del.onclick = async (e) => {
      e.stopPropagation();
      if (r.kind === 'folder') {
        if (!confirm('删除文件夹「' + r.name + '」？其中的笔记会回到根目录。')) return;
        await postJSON('/api/folder/del', { id: r.id });
      } else {
        if (!confirm('删除笔记「' + r.name + '」？')) return;
        await postJSON('/api/note/delete', { id: r.id });
        if (currentId === r.id) { currentId = null; $('#editor').value = ''; $('#preview').innerHTML = ''; $('#note-title').value = ''; $('#note-title').disabled = true; }
      }
      toast('已删除');
      loadTree();
    };
    el.appendChild(del);

    if (r.kind === 'note') {
      el.onclick = () => openNote(r.id);
    } else {
      el.onclick = async () => {
        const name = prompt('重命名文件夹', r.name);
        if (!name || name === r.name) return;
        await postJSON('/api/folder/rename', { id: r.id, name });
        toast('文件夹已重命名');
        loadTree();
      };
    }
    root.appendChild(el);
  });
}

function renderTags(notes) {
  const box = $('#tags');
  box.innerHTML = '';
  const all = [];
  notes.forEach(n => (n.tags || []).forEach(t => { if (!all.includes(t)) all.push(t); }));
  all.forEach(t => {
    const el = document.createElement('span');
    el.className = 'tag' + (activeTag === t ? ' on' : '');
    el.textContent = t;
    el.onclick = async () => {
      activeTag = (activeTag === t) ? null : t;
      const data = await loadTreeRaw();
      if (activeTag) {
        const filtered = data.notes.filter(n => (n.tags || []).includes(activeTag));
        renderTree(data.folders, filtered);
      }
      renderTags(data.notes);
    };
    box.appendChild(el);
  });
}

async function loadTreeRaw() { return await getJSON('/api/tree'); }

/* ---------- 打开与编辑 ---------- */
async function openNote(id) {
  const n = await getJSON('/api/note?id=' + encodeURIComponent(id));
  if (n.error) { toast('笔记不存在'); return; }
  currentId = id;
  currentTags = n.tags || [];
  $('#note-title').value = n.title;
  $('#note-title').disabled = false;
  $('#editor').value = n.content;
  setStatus('已加载 ' + n.updated.slice(11, 16));
  renderPreview(n.content);
  await loadTree();
}

function renderPreview(text) {
  clearTimeout(previewTimer);
  previewTimer = setTimeout(async () => {
    const r = await postJSON('/api/preview', { content: text });
    $('#preview').innerHTML = r.html || '';
  }, 140);
}

function scheduleSave() {
  dirty = true;
  setStatus('未保存');
  clearTimeout(saveTimer);
  saveTimer = setTimeout(saveNow, 700);
}

async function saveNow() {
  if (!currentId || !dirty) return;
  dirty = false;
  setStatus('保存中…');
  await postJSON('/api/save', { id: currentId, content: $('#editor').value });
  const t = new Date();
  setStatus('已保存 ' + String(t.getHours()).padStart(2, '0') + ':' + String(t.getMinutes()).padStart(2, '0'));
  await loadTree();
}

/* ---------- 导图 ---------- */
function renderMap(nodes) {
  const pad = 30, boxW = 186, boxH = 34;
  let maxX = 0, maxY = 0;
  nodes.forEach(n => { maxX = Math.max(maxX, n.x); maxY = Math.max(maxY, n.y); });
  const w = maxX + boxW + pad * 2;
  const h = maxY + boxH + pad * 2;

  let svg = '<svg width="' + w + '" height="' + h + '" viewBox="0 0 ' + w + ' ' + h + '">';
  svg += '<style>.mn{fill:#fff;stroke:#c9ced6;} .mt{font:12px "微软雅黑";fill:#111317;} .ml{fill:none;stroke:#c9ced6;}</style>';

  nodes.forEach(n => {
    if (!n.parent) return;
    const p = nodes.find(x => x.id === n.parent);
    if (!p) return;
    const x1 = p.x + boxW, y1 = p.y + boxH / 2 + pad;
    const x2 = n.x, y2 = n.y + boxH / 2 + pad;
    const mx = (x1 + x2) / 2;
    svg += '<path class="ml" d="M' + x1 + ' ' + y1 + ' C' + mx + ' ' + y1 + ',' + mx + ' ' + y2 + ',' + x2 + ' ' + y2 + '"/>';
  });

  nodes.forEach(n => {
    const x = n.x + pad, y = n.y + pad;
    svg += '<rect class="mn" x="' + x + '" y="' + y + '" width="' + boxW + '" height="' + boxH + '" rx="2"/>';
    const label = n.text.length > 14 ? n.text.slice(0, 14) + '…' : n.text;
    svg += '<text class="mt" x="' + (x + 10) + '" y="' + (y + 21) + '">' + escapeXml(label) + '</text>';
  });
  svg += '</svg>';
  $('#map').innerHTML = svg;
}

function escapeXml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

async function showMap() {
  if (!currentId) { toast('先选一篇笔记'); return; }
  const data = await getJSON('/api/mindmap?id=' + encodeURIComponent(currentId));
  if (!data.nodes || !data.nodes.length) { toast('这篇笔记还没有可成图的标题'); return; }
  renderMap(data.nodes);
  $('#editor-wrap').classList.add('hidden');
  $('#map-wrap').classList.remove('hidden');
  setStatus('导图：' + data.nodes.length + ' 个节点');
}

async function showSnapshots() {
  if (!currentId) { toast('先选一篇笔记'); return; }
  const data = await getJSON('/api/snapshots?id=' + encodeURIComponent(currentId));
  const items = data.items || [];
  let html = '<div class="pane-head">历史版本（' + items.length + '）<button class="btn btn-ghost btn-small" id="btn-back2">返回编辑</button></div>';
  if (!items.length) {
    html += '<div style="padding:24px;color:#8a8f98">还没有历史版本：保存过一次修改后就会生成。</div>';
  } else {
    html += '<div style="padding:8px 22px">';
    items.sort((a, b) => b.stamp.localeCompare(a.stamp));
    items.forEach(s => {
      html += '<div class="hit"><div class="hit-title">' + s.stamp + '</div>' +
        '<div class="hit-line">' + s.size + ' 字节 · <a href="#" data-stamp="' + s.stamp + '">恢复这一版</a></div></div>';
    });
    html += '</div>';
  }
  $('#map').innerHTML = html;
  $('#editor-wrap').classList.add('hidden');
  $('#map-wrap').classList.remove('hidden');
  const back = $('#btn-back2');
  if (back) back.onclick = backToEditor;
  $('#map').querySelectorAll('[data-stamp]').forEach(a => {
    a.onclick = async (e) => {
      e.preventDefault();
      const stamp = a.getAttribute('data-stamp');
      if (!confirm('恢复到 ' + stamp + '？当前内容会先自动存为一个新版本。')) return;
      const r = await postJSON('/api/restore', { id: currentId, stamp });
      $('#editor').value = r.content || '';
      renderPreview(r.content || '');
      backToEditor();
      toast('已恢复');
    };
  });
}

function backToEditor() {
  $('#map-wrap').classList.add('hidden');
  $('#editor-wrap').classList.remove('hidden');
}

/* ---------- 检索 ---------- */
let searchTimer = null;
function bindSearch() {
  $('#search').addEventListener('input', (e) => {
    const q = e.target.value.trim();
    clearTimeout(searchTimer);
    if (!q) { $('#search-results').classList.add('hidden'); return; }
    searchTimer = setTimeout(async () => {
      const data = await getJSON('/api/search?q=' + encodeURIComponent(q));
      const box = $('#search-results');
      box.innerHTML = '';
      if (!data.hits || !data.hits.length) {
        box.innerHTML = '<div style="padding:8px 0;color:#8a8f98;font-size:12px">没有命中</div>';
      } else {
        data.hits.forEach(h => {
          const el = document.createElement('div');
          el.className = 'hit';
          const title = document.createElement('div');
          title.className = 'hit-title';
          title.textContent = h.title;
          const line = document.createElement('div');
          line.className = 'hit-line';
          line.innerHTML = highlight(h.text, q);
          el.appendChild(title);
          el.appendChild(line);
          el.onclick = () => { openNote(h.id); toast('第 ' + h.line + ' 行命中'); };
          box.appendChild(el);
        });
      }
      box.classList.remove('hidden');
    }, 220);
  });
}

function highlight(text, q) {
  const safe = escapeXml(text);
  const qq = escapeXml(q);
  const i = safe.toLowerCase().indexOf(qq.toLowerCase());
  if (i < 0) return safe;
  return safe.slice(0, i) + '<b>' + safe.slice(i, i + qq.length) + '</b>' + safe.slice(i + qq.length);
}

/* ---------- 事件绑定 ---------- */
function bind() {
  $('#editor').addEventListener('input', (e) => {
    renderPreview(e.target.value);
    scheduleSave();
  });

  $('#note-title').addEventListener('change', async (e) => {
    if (!currentId) return;
    const v = e.target.value.trim();
    if (!v) return;
    await postJSON('/api/note/rename', { id: currentId, title: v });
    setStatus('标题已更新');
    loadTree();
  });

  $('#btn-new-note').onclick = async () => {
    const n = await postJSON('/api/note/new', { folder: '', title: '未命名笔记' });
    await loadTree();
    openNote(n.id);
    toast('已新建笔记');
  };

  $('#btn-new-folder').onclick = async () => {
    const name = prompt('文件夹名称', '新文件夹');
    if (!name) return;
    await postJSON('/api/folder/new', { parent: '', name });
    await loadTree();
    toast('已新建文件夹');
  };

  $('#btn-tag').onclick = async () => {
    if (!currentId) { toast('先选一篇笔记'); return; }
    const tag = prompt('标签名（已存在则取消该标签）', currentTags[0] || '');
    if (!tag) return;
    await postJSON('/api/tag', { id: currentId, tag });
    const n = await getJSON('/api/note?id=' + encodeURIComponent(currentId));
    currentTags = n.tags || [];
    await loadTree();
    toast('标签已更新：' + (currentTags.join('、') || '无'));
  };

  $('#btn-map').onclick = showMap;
  $('#btn-back').onclick = backToEditor;
  $('#btn-snapshots').onclick = showSnapshots;

  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault();
      saveNow();
      toast('已保存');
    }
  });

  window.addEventListener('beforeunload', () => { if (dirty) saveNow(); });
}

/* ---------- 启动 ---------- */
(async function init() {
  bind();
  bindSearch();
  const data = await loadTree();
  const params = new URLSearchParams(location.search);
  const wantId = params.get('id');
  const view = params.get('view');
  if (wantId) {
    await openNote(wantId);
  } else if (data.notes && data.notes.length) {
    await openNote(data.notes[0].id);
  } else {
    setStatus('还没有笔记，点「新建笔记」开始');
  }
  if (view === 'map') await showMap();
})();
