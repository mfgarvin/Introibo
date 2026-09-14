/* ---------------------------------------------------------------------------
   Opens the answer a deep link points at.

   The FAQ's rows are <details>, and every row carries an id so a reply to
   someone's feedback can link straight at one answer — /support#not-supported.
   Browsers scroll to a closed <details> and leave it closed, which lands the
   reader on the question they already knew they had. This opens it.

   Progressive enhancement, like theme.js: with JavaScript off every row still
   opens on click, and a deep link still scrolls to the right question. Nothing
   here leaves the browser, and nothing is stored.
--------------------------------------------------------------------------- */
(function () {
  'use strict';

  function revealHash() {
    var hash = window.location.hash;
    if (!hash || hash.length < 2) return;

    var target;
    try {
      target = document.querySelector(hash);
    } catch (e) {
      return;  // a hash that isn't a valid selector
    }
    if (!target) return;

    // The id may be on the <details> itself or on something inside it.
    var row = target.closest ? target.closest('details') : null;
    if (!row) return;

    row.open = true;
    // Re-scroll: the browser aimed at a collapsed row, so the position it
    // settled on is now wrong by the height of whatever just unfolded.
    row.scrollIntoView({ block: 'start' });
  }

  revealHash();
  window.addEventListener('hashchange', revealHash);
})();
