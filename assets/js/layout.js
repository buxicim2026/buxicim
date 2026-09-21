/**
 * layout.js —— 公共布局注入与交互
 *  1. 把 partials/header.html、partials/footer.html 注入到 [data-include] 占位
 *  2. 当前页导航高亮、移动端汉堡菜单、返回顶部按钮
 *  3. 把 site.js 里的品牌配置绑定到 [data-bind-*] 元素
 *
 * 注意：使用了 fetch + ES Module，必须通过 http(s) 打开页面（不能 file://）。
 */

import { site, platforms } from '../data/site.js';

const currentPage = () => {
  const file = location.pathname.split('/').pop();
  return file === '' ? 'index.html' : file;
};

/** 注入公共头尾 */
async function injectPartials() {
  const nodes = document.querySelectorAll('[data-include]');
  await Promise.all(
    [...nodes].map(async (node) => {
      const name = node.getAttribute('data-include');
      try {
        // partials 在站点根目录：assets/js/layout.js → 上两级
        const url = new URL(`../../partials/${name}.html`, import.meta.url);
        const res = await fetch(url);
        if (!res.ok) throw new Error(String(res.status));
        node.outerHTML = await res.text();
      } catch (err) {
        // 注入失败不白屏：保留占位并给出可见提示
        console.warn(`[layout] 注入 ${name} 失败：`, err);
        node.innerHTML = `<p class="text-sm text-muted">${name} 片段加载失败，请用本地服务器（npx serve）打开页面。</p>`;
      }
    })
  );
}

/** 导航高亮 */
function markActiveNav() {
  const page = currentPage();
  document.querySelectorAll('#navLinks a[href]').forEach((a) => {
    const href = a.getAttribute('href');
    if (href === page) {
      a.classList.add('is-active');
      a.setAttribute('aria-current', 'page');
    }
  });
}

/** 移动端汉堡菜单 */
function bindNavToggle() {
  const toggle = document.getElementById('navToggle');
  const links = document.getElementById('navLinks');
  if (!toggle || !links) return;

  const setOpen = (open) => {
    links.classList.toggle('is-open', open);
    toggle.classList.toggle('is-open', open);
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? '关闭菜单' : '打开菜单');
    document.body.classList.toggle('nav-open', open);
  };

  toggle.addEventListener('click', () => setOpen(!links.classList.contains('is-open')));
  links.addEventListener('click', (e) => {
    if (e.target.closest('a')) setOpen(false);
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') setOpen(false);
  });
}

/** 返回顶部按钮 */
function mountBackToTop() {
  const btn = document.createElement('button');
  btn.className = 'back-to-top';
  btn.type = 'button';
  btn.setAttribute('aria-label', '返回顶部');
  btn.innerHTML = '<span aria-hidden="true">↑</span>';
  document.body.appendChild(btn);

  const onScroll = () => btn.classList.toggle('is-visible', window.scrollY > 480);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  btn.addEventListener('click', () =>
    window.scrollTo({ top: 0, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
  );
}

/** 把配置里的品牌信息绑到页面元素 */
function bindConfig() {
  document.querySelectorAll('[data-bind-name]').forEach((el) => (el.textContent = site.name));
  document.querySelectorAll('[data-bind-slogan]').forEach((el) => (el.textContent = site.slogan));
  document.querySelectorAll('[data-bind-intro]').forEach((el) => (el.textContent = site.intro));
  document.querySelectorAll('[data-year]').forEach((el) => (el.textContent = String(new Date().getFullYear())));

  // 平台链接：按 data-platform 键绑定 href
  document.querySelectorAll('[data-platform]').forEach((el) => {
    const key = el.getAttribute('data-platform');
    const p = platforms.find((item) => item.key === key);
    if (!p) return;
    if (p.url) {
      el.setAttribute('href', p.url);
      el.setAttribute('target', '_blank');
      el.setAttribute('rel', 'noopener');
    } else {
      // 链接未配置：降级为不可用状态，提示待补充
      el.setAttribute('href', 'contact.html');
      el.classList.add('is-disabled');
      el.setAttribute('title', '链接待补充，可先通过联系页找到我们');
    }
  });
}

(async function init() {
  await injectPartials();
  markActiveNav();
  bindNavToggle();
  bindConfig();
  mountBackToTop();
  document.documentElement.classList.add('layout-ready');
  document.dispatchEvent(new CustomEvent('layout:injected'));
})();
