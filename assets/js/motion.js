/**
 * motion.js —— 滚动入场动画与数字滚动
 * 只用 IntersectionObserver，触发后立即 unobserve；尊重 prefers-reduced-motion。
 */

const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/** 滚动入场：.reveal → .is-in */
function initReveal() {
  const items = document.querySelectorAll('.reveal');
  if (!items.length) return;

  if (reduceMotion || !('IntersectionObserver' in window)) {
    items.forEach((el) => el.classList.add('is-in'));
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      });
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.12 }
  );

  items.forEach((el) => io.observe(el));
}

/** 数字滚动：元素上加 data-count="1189" */
function initCounters() {
  const counters = document.querySelectorAll('[data-count]');

  const run = (el) => {
    const target = Number(el.getAttribute('data-count')) || 0;
    if (reduceMotion) {
      el.textContent = target.toLocaleString('zh-CN');
      return;
    }
    const duration = 1100;
    const start = performance.now();
    const step = (now) => {
      const p = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      el.textContent = Math.round(target * eased).toLocaleString('zh-CN');
      if (p < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };

  if (!('IntersectionObserver' in window)) {
    counters.forEach(run);
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        run(entry.target);
        io.unobserve(entry.target);
      });
    },
    { threshold: 0.4 }
  );

  counters.forEach((el) => io.observe(el));
}

/** 导航滚动态：滚动后加深导航背景 */
function initNavScrollState() {
  const nav = document.getElementById('siteNav');
  if (!nav) return;
  const onScroll = () => nav.classList.toggle('is-scrolled', window.scrollY > 24);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

document.addEventListener('DOMContentLoaded', () => {
  initReveal();
  initCounters();
  initNavScrollState();
});

// 头尾由 layout.js 异步注入，注入完成后再补一次扫描
document.addEventListener('layout:injected', () => initNavScrollState());
