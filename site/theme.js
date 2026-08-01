/* ---------------------------------------------------------------------------
   Light/dark switch. The stylesheet already honours :root[data-theme]; this is
   the only thing that sets it.

   Loaded synchronously in <head> on purpose: the attribute has to be on <html>
   before first paint, or a viewer whose saved choice differs from their OS
   preference gets a flash of the wrong theme.

   Progressive enhancement — the button is built here rather than sitting in the
   markup, so a viewer without JS gets their OS preference and no dead control.
   Nothing here leaves the browser; the choice lives in localStorage.
--------------------------------------------------------------------------- */
(function () {
  'use strict';

  var KEY = 'pf-theme';

  function stored() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }  // private mode
  }

  function osPrefersDark() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  // Only write the attribute when there is a saved choice. Leaving it off lets
  // the @media query stay in charge, which is what an untouched page should do.
  var saved = stored();
  if (saved === 'dark' || saved === 'light') {
    document.documentElement.setAttribute('data-theme', saved);
  }

  function current() {
    return document.documentElement.getAttribute('data-theme') ||
           (osPrefersDark() ? 'dark' : 'light');
  }

  var SUN = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 17a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-2a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM11 1h2v3h-2zm0 19h2v3h-2zM1 11h3v2H1zm19 0h3v2h-3zM3.5 4.9l1.4-1.4 2.1 2.1-1.4 1.4zM17 18.4l1.4-1.4 2.1 2.1-1.4 1.4zM18.4 7l-1.4-1.4 2.1-2.1L20.5 4.9zM5.6 20.5 4.2 19.1l2.1-2.1 1.4 1.4z"/></svg>';
  var MOON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12.3 2a9 9 0 1 0 9.7 12.1A7.5 7.5 0 0 1 12.3 2z"/></svg>';

  function render(btn) {
    var dark = current() === 'dark';
    // The label names what the button will *do*, not the state it is in.
    btn.innerHTML = (dark ? SUN : MOON) + '<span>' + (dark ? 'Light' : 'Dark') + '</span>';
    btn.setAttribute('aria-label', 'Switch to ' + (dark ? 'light' : 'dark') + ' theme');
  }

  function mount() {
    var bar = document.querySelector('.topbar');
    if (!bar) return;

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'theme-toggle';
    render(btn);

    btn.addEventListener('click', function () {
      var next = current() === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem(KEY, next); } catch (e) { /* nothing to do */ }
      render(btn);
    });

    bar.appendChild(btn);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mount);
  } else {
    mount();
  }
})();
