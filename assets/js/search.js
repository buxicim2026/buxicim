/**
 * search.js —— 站内搜索
 * 数据源：assets/data/search-index.json（新增页面时手动补一条即可）
 * 支持：URL ?q=关键词 直接进入结果、关键词高亮、空态提示
 */

const $input = document.getElementById('searchInput');
const $results = document.getElementById('searchResults');
const $meta = document.getElementById('searchMeta');

let index = [];

const escapeHtml = (s) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

/** 高亮关键词（先转义再插入 mark，避免 XSS） */
function highlight(text, keyword) {
  const safe = escapeHtml(text);
  if (!keyword) return safe;
  const kw = escapeHtml(keyword).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return safe.replace(new RegExp(kw, 'gi'), (m) => `<mark>${m}</mark>`);
}

function score(item, q) {
  const hay = `${item.title} ${item.desc} ${item.keywords || ''}`.toLowerCase();
  const needle = q.toLowerCase();
  if (!needle) return 0;
  if (item.title.toLowerCase().includes(needle)) return 3;
  if ((item.keywords || '').toLowerCase().includes(needle)) return 2;
  if (hay.includes(needle)) return 1;
  // 退化为逐字匹配，容忍「实时字幕」这类跨字段输入
  return [...needle].every((ch) => hay.includes(ch)) ? 0.5 : 0;
}

function render(list, q) {
  if (!q) {
    $meta.textContent = `共收录 ${index.length} 条内容，输入关键词开始搜索。`;
    $results.innerHTML = list
      .map(
        (item) => `
        <article class="result-item">
          <h3><a href="${item.url}">${escapeHtml(item.title)}</a></h3>
          <p>${escapeHtml(item.desc)}</p>
        </article>`
      )
      .join('');
    return;
  }

  $meta.textContent = list.length
    ? `找到 ${list.length} 条与「${q}」相关的内容`
    : `没有找到与「${q}」相关的内容，换个关键词试试。`;

  $results.innerHTML = list
    .map(
      (item) => `
      <article class="result-item">
        <h3><a href="${item.url}">${highlight(item.title, q)}</a></h3>
        <p>${highlight(item.desc, q)}</p>
      </article>`
    )
    .join('');

  if (!list.length) {
    $results.innerHTML += `
      <div class="notice">
        <span>🔍</span>
        <div>也可以直接去 <a href="plugin.html">插件页</a> 或 <a href="contact.html">联系页</a> 看看。</div>
      </div>`;
  }
}

function run(q) {
  const keyword = q.trim();
  const list = index
    .map((item) => ({ item, s: score(item, keyword) }))
    .filter((x) => (keyword ? x.s > 0 : true))
    .sort((a, b) => b.s - a.s)
    .map((x) => x.item);
  render(list, keyword);

  const url = new URL(location.href);
  if (keyword) url.searchParams.set('q', keyword);
  else url.searchParams.delete('q');
  history.replaceState(null, '', url);
}

async function init() {
  if (!$input || !$results) return;
  try {
    const res = await fetch(new URL('../data/search-index.json', import.meta.url));
    index = await res.json();
  } catch (err) {
    console.warn('[search] 索引加载失败：', err);
    $meta.textContent = '搜索索引加载失败，请用本地服务器（npx serve）打开页面。';
    return;
  }

  const params = new URLSearchParams(location.search);
  const q = params.get('q') || '';
  $input.value = q;
  run(q);

  let timer;
  $input.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(() => run($input.value), 160);
  });
}

document.addEventListener('DOMContentLoaded', init);
