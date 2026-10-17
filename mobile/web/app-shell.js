// Public assets only. Private API responses and the browser database never enter this cache.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
// Keep pre-migration preparations reachable on the same origin.
try {
  if (localStorage.getItem('statoo-registration-draft') || sessionStorage.getItem('statoo-connection')) {
    const link = document.createElement('a');
    link.href = 'portal/';
    link.textContent = 'Retrouver mes préparations dans l’ancien portail';
    link.setAttribute('aria-label', link.textContent);
    link.style.cssText = 'position:fixed;bottom:8px;right:8px;z-index:20;max-width:90%;padding:8px 12px;background:#141a22;color:#f8fafc;border:1px solid #22c55e;border-radius:12px;font:12px system-ui;';
    document.body.append(link);
  }
} catch {}
