# ParishFinder site copy

Every piece of text on the site, pulled out for editing. Edit this file freely,
then hand it back and it gets written into `index.html` and `privacy.html`.

**This file is a working document, not the source of truth.** The HTML is what
ships. Nothing reads this file at build time — there is no build step.

## How to edit

- Change the text after each `>` marker. Leave the `###` headings and the
  `[id]` tags alone — they are how each block is matched back to its place in
  the HTML.
- Inline formatting is markdown and maps to real tags:
  `*italic*` → `<em>`, `**bold**` → `<strong>`, `[text](url)` → `<a href>`.
  Keep them if you want the emphasis kept.
- `~` marks a non-breaking space (`&nbsp;`) — a spot where a line break would
  look wrong. Move it or drop it as you like.
- To delete a block entirely, write `> (remove)`.
- To add a new feature card or list item, copy an existing one and give it a
  new id; the id just has to be unique.

---

# index.html

## Metadata

### Page title [meta.title]
> ParishFinder — Discover Liturgies and Events around the Diocese

### Meta description [meta.description]
> Find Mass schedules and more for parishes across the Diocese of Cleveland.

### Social share title [meta.og.title]
> ParishFinder — Discover the Life of the Church

### Social share description [meta.og.description]
> Find Mass schedules and more for parishes around the Diocese of Cleveland.

## Hero

### Eyebrow [hero.eyebrow]
> Diocese of Cleveland / Northeast Ohio

### Headline [hero.h1]
> Discover the *Life* of the Church

### Lede [hero.lede]
> Mass, confession, and adoration across 189 Catholic parishes — the feasts, the hours, and what's happening today, gathered from the bulletins so you don't have to hunt through them.

### Button [hero.cta]
> Tell me when it launches

### Button email subject line [hero.cta.subject]
> ParishFinder — tell me when it launches

### Note beside the button [hero.note]
> Coming soon to Google~Play and the Apple App Store 

### App icon alt text [hero.icon.alt]
> The ParishFinder app icon: a gold church in a stained-glass roundel.

> Screen-reader description of the app icon beside the headline. It is not shown
> on screen. The image itself is generated — see `README.md`.

## Section: What it does

### Heading [features.h2]
> What it does

### Intro [features.intro]
> Everything works from one screen, and everything keeps working without a signal.

### Feature 1 title [feature.next-mass.title]
> The next Mass

### Feature 1 body [feature.next-mass.body]
> Open the app and see the next Mass starting near you, with the parish and how long you have to get there.

### Feature 2 title [feature.map.title]
> Parishes near you

### Feature 2 body [feature.map.body]
> A map of what's around you. Swipe the carousel for schedules, or tap a marker for the full parish page.

### Feature 3 title [feature.search.title]
> Search that understands you

### Feature 3 body [feature.search.body]
> By name, city, or ZIP. “St”, “St.”, “Saint”, and “Sts” all find what you meant.

### Feature 4 title [feature.confession.title]
> Confession & adoration

### Feature 4 body [feature.confession.body]
> Filter for parishes offering either, sorted by distance or by what's happening soonest. Perpetual chapels are marked.

### Feature 5 title [feature.favorites.title]
> Your home parishes

### Feature 5 body [feature.favorites.body]
> Keep the parishes you actually attend at the top, one tap away.

### Feature 6 title [feature.liturgy.title]
> The liturgical day

### Feature 6 body [feature.liturgy.body]
> Today's feast, saint, and season at a glance — computed on your phone, so it's right even offline.

## Section: Built from the bulletins

### Heading [coverage.h2]
> Built from the bulletins

### Big number [coverage.figure]
> 189

### Text beside the number [coverage.caption]
> parishes across Cuyahoga, Summit, and the surrounding counties — each schedule read out of a real parish bulletin or website rather than guessed at.

### Paragraph below [coverage.body]
> Times change, especially around holy days. Every parish page has a one-tap way to confirm what's right or report what isn't, and those corrections come straight to the person maintaining the data. Where a schedule couldn't be verified, the app says so rather than pretending otherwise.

## Section: Privacy

### Heading [privacy.h2]
> No ads. No accounts. No tracking.

### Point 1 [privacy.point.location]
> **Your location never leaves your phone.** It's used on the device to centre the map and sort by distance — it is never transmitted or stored.

### Point 2 [privacy.point.accounts]
> **There's nothing to sign up for.** No account, no email required, no profile.

### Point 3 [privacy.point.tracking]
> **No analytics, no advertising, no third-party SDKs.** Even the typefaces on this page are served from here rather than from Google.

### Point 4 [privacy.point.offline]
> **It works offline.** Schedules are cached on your phone — including in a church basement with no signal.

### Link below the panel [privacy.link]
> [Read the full privacy policy](privacy.html)

## Footer

### Line 1 [footer.line1]
> **ParishFinder** — Mass times for Greater Cleveland and Akron.

### Line 2 [footer.line2]
> Not affiliated with or endorsed by the Roman Catholic Diocese of Cleveland.

### Line 3 — attributions [footer.line3]
> Map data © OpenStreetMap contributors. Monstrance icon by Ahmad Roaayala, Noun Project (CC BY 3.0). Inter and Cormorant Garamond under the SIL Open Font License 1.1.

> **Keep the attributions.** The monstrance icon is CC BY 3.0 and the fonts are
> OFL 1.1 — both licences require this credit. Reword it if you like, but the
> names and licences have to stay.

### Footer link — privacy [footer.link.privacy]
> Privacy policy

---

# privacy.html

### Page title [pp.meta.title]
> Privacy Policy — ParishFinder

### Meta description [pp.meta.description]
> ParishFinder's privacy policy. No accounts, no advertising, no analytics. Your location never leaves your device.

### Back link [pp.back]
> ← ParishFinder

### Heading [pp.h1]
> Privacy Policy

### Last-updated date [pp.updated]
> Last updated 28 July 2026

### Lead paragraph [pp.lead]
> ParishFinder has no accounts, no advertising, and no analytics or tracking. It does not build a profile of you, and it never sells or shares personal information. The only information that leaves your device is what you deliberately submit through the feedback form.

## Information the app handles

### Heading [pp.handles.h2]
> Information the app handles

### Location heading [pp.location.h3]
> Location

### Location paragraph 1 [pp.location.p1]
> If you use the Map tab and grant location permission, the app reads your device's approximate or precise location. Your location is used **only on your device**, to centre the map near you and to sort parishes by distance. It is **not transmitted to us**, not stored after the screen is closed, and not shared with anyone.

### Location paragraph 2 [pp.location.p2]
> Location permission is optional. If you decline it, every other part of the app — search, parish details, schedules, home parishes — continues to work; the map simply opens at a default view of the region. You can revoke location access at any time in Android Settings → Apps → ParishFinder → Permissions.

### Feedback heading [pp.feedback.h3]
> Feedback you submit

### Feedback intro [pp.feedback.intro]
> Parish pages include an “Is this information accurate?” prompt. If you choose to submit feedback, the following is sent to our server and stored:

### Feedback list item 1 [pp.feedback.item1]
> Whether you marked the data accurate or reported an issue

### Feedback list item 2 [pp.feedback.item2]
> The categories you selected (for example Mass times, phone number)

### Feedback list item 3 [pp.feedback.item3]
> Any free-text details you typed

### Feedback list item 4 [pp.feedback.item4]
> The parish name and identifier the feedback refers to

### Feedback list item 5 [pp.feedback.item5]
> Your email address — **only if you choose to enter one** so we can reply

### Feedback list item 6 [pp.feedback.item6]
> The app version, build number, and platform

### Feedback list item 7 [pp.feedback.item7]
> Your IP address

### IP paragraph [pp.feedback.ip]
> The IP address is recorded solely to rate-limit submissions and prevent abuse of the form. It is not used to identify you, is never combined with your location, and is not shared with third parties.

### Storage paragraph [pp.feedback.storage]
> Feedback is stored on Cloudflare and used only to correct and improve parish data. If you include an email address, it is used only to reply to you about that submission. **Please do not include sensitive personal information in the free-text field.**

### On-device heading [pp.device.h3]
> Data stored on your device

### On-device intro [pp.device.intro]
> The app saves the following locally. None of it is transmitted to us:

### On-device item 1 [pp.device.item1]
> Your saved home parishes

### On-device item 2 [pp.device.item2]
> A cached copy of the parish directory, so the app works offline

### On-device item 3 [pp.device.item3]
> A cached copy of the liturgical calendar

### On-device item 4 [pp.device.item4]
> A flag recording that you have seen the first-run notice

### On-device item 5 [pp.device.item5]
> Your light/dark theme preference

### On-device closing [pp.device.closing]
> All of this is removed when you uninstall the app or clear its storage.

## Third-party services

### Heading [pp.third.h2]
> Third-party services

### Intro [pp.third.intro]
> Using the app causes your device to contact these services directly. Each will see your device's IP address as a normal part of serving a request:

### Table column headings [pp.third.table.head]
> Service | Purpose | Privacy policy

### Table row 1 [pp.third.row.github]
> GitHub | Downloads the parish directory | [Statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)

### Table row 2 [pp.third.row.osm]
> OpenStreetMap | Map tiles on the Map tab | [Policy](https://osmfoundation.org/wiki/Privacy_Policy)

### Table row 3 [pp.third.row.calapi]
> calapi.inadiutorium.cz | Liturgical calendar | [Site](https://calapi.inadiutorium.cz)

### Table row 4 [pp.third.row.cloudflare]
> Cloudflare | Receives and stores feedback | [Policy](https://www.cloudflare.com/privacypolicy/)

### Closing paragraph [pp.third.closing]
> The app's typefaces are bundled inside the app, so it never contacts Google's font servers. We do not use advertising networks, analytics SDKs, crash-reporting services, or social media SDKs.

## Children's privacy

### Heading [pp.children.h2]
> Children's privacy

### Body [pp.children.body]
> ParishFinder is intended for a general audience and is safe for all ages. It does not knowingly collect personal information from children. Because there are no accounts and no tracking, the app collects nothing about any user beyond the feedback described above.

## Data retention and your choices

### Heading [pp.retention.h2]
> Data retention and your choices

### Item 1 [pp.retention.item1]
> **Location** is never retained by us, because it never reaches us.

### Item 2 [pp.retention.item2]
> **Feedback records** are kept while they are useful for correcting parish data. You may request deletion at any time.

### Item 3 [pp.retention.item3]
> **On-device data** is under your control: clear the app's storage or uninstall it.

### Deletion request paragraph [pp.retention.request]
> To request access to or deletion of feedback you have submitted, email [contact@parishfinder.app](mailto:contact@parishfinder.app) with enough detail to identify the submission — for example the parish and roughly when you sent it.

## Accuracy disclaimer

### Heading [pp.accuracy.h2]
> Accuracy disclaimer

### Body [pp.accuracy.body]
> Mass, confession, and adoration times are compiled from publicly available parish bulletins and websites. They can change without notice, particularly around holy days and holidays. ParishFinder makes no guarantee of accuracy — please confirm with the parish directly before travelling.

## Changes to this policy

### Heading [pp.changes.h2]
> Changes to this policy

### Body [pp.changes.body]
> If this policy changes materially, the date above will change and the revised policy will be posted at this address. Continued use of the app after an update constitutes acceptance of the revised policy.

## Contact

### Heading [pp.contact.h2]
> Contact

### Body [pp.contact.body]
> Questions about this policy or your data: [contact@parishfinder.app](mailto:contact@parishfinder.app)

---

# Things to know before editing

- **The contact address is `contact@parishfinder.app`** and appears in four
  places above. It is also in the app itself and in `PRIVACY.md`. If you change
  it here, say so — it needs changing in those too.

- **`PRIVACY.md` in the repo root is the same policy in markdown.** If you edit
  the privacy text here, that file needs the same edit or the two will drift.
  The hosted page is what Play and users actually see.

- **The "189 parishes" figure appears three times** — the meta description, the
  hero lede, and the big number. It comes from the live `export.json`, so all
  three move together when the dataset grows.

- **The privacy claims are load-bearing.** Statements like "your location never
  leaves your phone" and "no analytics" are what the app was built to be able to
  say, and Play's Data Safety form is filled out to match. If you soften or
  strengthen any of them, `docs/play-data-safety.md` needs to agree.

- **The launch CTA is a placeholder.** "Tell me when it launches" and "Coming
  soon to Google Play" both need replacing with a real Play badge and store link
  once the listing is live.
