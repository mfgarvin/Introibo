# parishfinder.app — landing page

Static, self-contained site. No build step, no framework, no external requests
of our own.

```
site/
  index.html      landing page
  support.html    help + FAQ — the support URL on both store listings
  privacy.html    privacy policy — Play requires this at a public URL
  404.html        served by Pages for any unknown path
  robots.txt      crawl everything; points at the sitemap
  sitemap.xml     three URLs, written by hand — add a page, add a line
  style.css       shared tokens + styles for every page
  theme.js        light/dark switch, on every page
  faq.js          opens the FAQ row a deep link names; support.html only
  fonts/          Inter + Cormorant Garamond, self-hosted, with their OFL texts
  badge-*.{svg,png}   official App Store / Google Play badges, unmodified
  shot-*.png      app screenshots, framed (generated — see below)
```

**Cloudflare injects two scripts of its own** at the edge — the Web Analytics
beacon, and Scrape Shield's email decoder, which rewrites every
`mailto:contact@parishfinder.app` into a link a script has to reassemble. So
the two scripts in this repo are not the only scripts on the page, and with
JavaScript off the contact address renders as `[email protected]`. Both come
from Pages settings, not from anything here.

## Preview locally

Open `index.html` directly in a browser, or:

```bash
cd site && python3 -m http.server 8000
```

## Deploy

Upload the whole `site/` directory as the document root. Any static host works —
Cloudflare Pages is the natural fit since the feedback Worker is already on
Cloudflare.

Links point at the extensionless `/privacy` and `/support`, which is what
Cloudflare Pages actually serves — it 308-redirects the `.html` forms to them,
so linking `privacy.html` internally cost every click a redirect. The app links
to `/privacy` too. **On a host without that behaviour (GitHub Pages), these
become dead links** — add the extensions back, or add redirects.

`404.html` is picked up by Pages automatically for unknown paths. Before it
existed every wrong URL returned the *landing page* with a `200`, which search
engines file as a duplicate of the homepage.

## Things to keep in sync

- **`privacy.html` and the repo's `PRIVACY.md` are the same policy in two
  formats.** Edit both, or the hosted version will drift from the one under
  version control. The hosted one is what Play and users actually see.
- **`support.html` describes app behaviour** — the ZIP fallback, the feedback
  prompt's exact wording, the 24-hour refresh, Android 7.0 / iOS 15, and two
  counted figures (six repeated parish names, fourteen unverified parishes). It
  is the page both stores link as the support URL, so a user lands there
  *because* something confused them. If the app or the data changes, this page
  is wrong until it follows.
- **Every FAQ row's `id` is a published anchor.** They are what a reply to
  someone's feedback links at (`/support#not-supported`). Reword a question
  freely; renaming its id breaks links already sent.
- **The "180+ parishes" figure** on the landing page is a deliberate floor, not
  a live count (it was an exact 184 until 2026-08-06). It appears twice — hero
  lede and big number — and `docs/play-listing.md` must agree.
- **The hero shows one badge and a note.** iOS went live 2026-09-18 and Google
  Play had not, so the App Store badge is real — Apple ID `6803622742` — while
  a quiet `<p class="play-soon">` ("Coming soon to Google Play") holds the
  second badge's place. That note is inert copy: no button, no waiting list.
  **When Play publishes, it is two edits**: delete the `PLAY-OFF` / `PLAY-ON`
  fence lines around the Play anchor in `index.html`, and delete the
  `play-soon` paragraph. The Play URL needs no id — it is keyed on the
  application id `app.parishfinder`.
- **The badge artwork must not be edited.** `badge-app-store.svg` came from
  Apple's Marketing Tools badge API and `badge-google-play.png` from Google's
  badge generator; both licences require the artwork unmodified. The CSS only
  sizes them, and the two heights differ on purpose — Google's file has its
  required clear space baked into the image, Apple's does not. That asymmetry
  is also why `.badge-apple` carries `margin-inline-start: -10px`: it pulls
  Apple's added clear space back off the page gutter so the artwork lines up
  with the lede above, which Google's transparent padding already does.

## Screenshots

The landing page's "What it looks like" section is live, showing
`shot-home.png` and `shot-parish.png`. Both are generated, not hand-cropped:

```bash
python3 tool/site_screenshots.py screenshots/home.png screenshots/parish.png
```

That writes them at 660 px wide — half the source capture, still 2× on a retina
display, about a fifth the bytes — and **keeps the alpha channel**.

The captures come from `tool/framed_screenshot.py`, so the phone's body is
already part of the image and the ground around it is transparent. Two
consequences for the CSS, both in `style.css`:

- **No bezel, corners or border of our own.** The frame is in the pixels.
- **`filter: drop-shadow`, never `box-shadow`.** A box shadow traces the
  image's bounding rectangle and would draw a hard-edged box behind a rounded
  phone; drop-shadow follows the alpha. Dark mode adds a faint candlelight rim,
  because near-black phone art on the dark ground loses its own edge.

Feed it release or **profile** captures — never a debug build, which carries the
DEBUG ribbon and `kDevLocation`'s Lakewood mock.

## Design notes

Palette and typefaces are the app's own, from `CLAUDE.md` — parchment `#FAF6EE`
over oxblood `#8C1F1F` with gold `#C9A227` used strictly as ornament. Gold never
carries text; `#8C5A14` (light) and `#D4A24A` (dark) do that job, because
`#C9A227` is too pale to meet contrast on parchment.

**Dark mode deliberately does not use the app's OLED `#000000`.** On a phone that
black saves power and the content is a narrow column; across a wide page it
turned the warm palette into a void and made the gold glare against it. The site
uses a warm plum-black instead — `#17100F` ground, `#241A18` surfaces — so night
reads as the same parchment world after dark rather than a different product.
If you ever sync tokens back from the app, keep this one diverging on purpose.

The page's one texture is the **quarry diaper** — the faint diagonal lattice the
app's `_StainedGlassPainter` strokes across a parish header. It's on `<body
class="diaper">` at ~5% alpha. It's the only ornament borrowed from the app's
own drawing code rather than invented for the web, which is what makes the site
feel like the same object as the app.

`theme.js` is loaded synchronously in `<head>` so `[data-theme]` lands before
first paint (otherwise a viewer whose saved choice differs from the default gets
a flash of the wrong theme), and it *builds* the toggle button rather than the
markup shipping one — no JS, no dead control. The choice is kept in
`localStorage`; nothing leaves the browser.

**Light is the default, and `prefers-color-scheme` is deliberately not
consulted.** The app behaves the same way: a fresh install lands on light and
following the system is an opt-in from Settings. The site has no third "system"
state, so there is no `@media (prefers-color-scheme: dark)` block in
`style.css` at all — dark is reached only through `[data-theme="dark"]`, which
the toggle sets. Adding the media query back would split behaviour between
JS-on and JS-off viewers.

`faq.js` is the second and last script here, and it is on `support.html` only.
The FAQ's rows are `<details>`, so they open and close with no script at all;
what the script adds is one thing the element cannot do — a link to
`/support#not-supported` scrolls to a *closed* row, which lands the reader on
the question they already had. It opens the row the hash names, and re-scrolls
once the answer has unfolded. Deferred, not blocking, because nothing about
first paint depends on it.

Fonts are served from `fonts/` rather than a CDN. That's deliberate and matches
the app, which bundles them: nothing about a visitor reaches a third party.

The hero image is the real app icon, `app-icon-544.png`, generated by
`tool/gen_icons.py` along with the favicon and apple-touch icon. **Don't
hand-edit those files** — change the script and re-run it. It's rendered at 544px
for a ~272px slot so it stays sharp on retina displays, and CSS rounds the
corners to 22.5% so the site shows it in the same superellipse shape a phone home
screen will.

It replaced a CSS-drawn leaded lancet window. Showing the actual icon is more
useful on a page whose job is to advertise an app — people recognise what they're
about to install.
