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
> ParishFinder — An app for the Diocese of Cleveland

### Meta description [meta.description]
> A free mobile app for finding Mass schedules and more across the Diocese of Cleveland.

### Social share title [meta.og.title]
> ParishFinder — Discover the Life of the Church

### Social share description [meta.og.description]
> A free mobile app for finding Mass schedules and more around the Diocese of Cleveland.

## Hero

### Eyebrow [hero.eyebrow]
> An app for the Diocese of Cleveland / Northeast Ohio

### Headline [hero.h1]
> Discover the *Life* of the Church

### Lede [hero.lede]
> A free app for your phone: Masses, confession, and adoration across 180+ Catholic parishes — the feasts, the hours, and what's happening today, gathered from the bulletins so you don't have to hunt through them.

### Coming-soon badge [hero.note]
> Coming soon to Google~Play and the Apple~App~Store

> There is no button and no waiting list — this is a status badge, not a
> control. Replace it with real store links once the listings are live.

### App icon alt text [hero.icon.alt]
> The ParishFinder app icon: a gold church in a stained-glass roundel.

> Screen-reader description of the app icon beside the headline. It is not shown
> on screen. The image itself is generated — see `README.md`.

## Section: What it does

### Heading [features.h2]
> What is it?

### Intro [features.intro]
> A mobile app that puts the parishes around you in the palm of your hand. Find what you need quickly for the parishes nearby!

### Feature 1 title [feature.next-mass.title]
> The next Mass

### Feature 1 body [feature.next-mass.body]
> Open the app and see the next Mass starting near you, with the parish and how long you have to get there.

### Feature 2 title [feature.map.title]
> Parishes near you

### Feature 2 body [feature.map.body]
> New to the area? Look at a map of what's around you. Swipe the carousel for schedules, or tap a marker for the full parish page.

### Feature 3 title [feature.search.title]
> Search that understands you

### Feature 3 body [feature.search.body]
> Easily find the church you're looking for.

### Feature 4 title [feature.confession.title]
> Confession & adoration

### Feature 4 body [feature.confession.body]
> Whether you're planning ahead or the Spirit is moving you now, find where Confession and Adoration are being offered.

### Feature 5 title [feature.favorites.title]
> Your home parishes

### Feature 5 body [feature.favorites.body]
> Keep the parishes you call home easily accessible, one tap away.

### Feature 6 title [feature.liturgy.title]
> The liturgical day

### Feature 6 body [feature.liturgy.body]
> Wondering what orations will be used? See today's feast, saint, or season at a glance.

## Section: Built from the bulletins

### Heading [coverage.h2]
> Compiled from bulletins

### Big number [coverage.figure]
> 180+

### Text beside the number [coverage.caption]
> parishes across the 8 counties of the Diocese of Cleveland — each schedule is pulled from the parish bulletin, *the* most up-to-date resource at a parish.

### Paragraph below [coverage.body]
> Times change, especially around the holidays or holy days. In case something is missed, feedback can be given on a parish's data, crowdsourcing any changes that might need to be made. If we can't verify a parish's schedule, we'll let you know!

## Section: Privacy

### Heading [privacy.h2]
> No ads. No accounts. No tracking.

### Point 1 [privacy.point.location]
> **Your location never leaves your phone.** It's used on the device to center the map and sort by distance — it is never transmitted or stored.

### Point 2 [privacy.point.accounts]
> **There's nothing to sign up for.** No account, no email required, no profile. And it's totally free.

### Point 3 [privacy.point.tracking]
> **No analytics, no advertising, no third-party SDKs.** We're not here to sell you ads. We're here to get you to church.

### Point 4 [privacy.point.offline]
> **It works offline.** Schedules are cached on your phone — after setting it up once, it'll work anywhere, even in the parish hall that has absolutely no reception.

### Link below the panel [privacy.link]
> [Read the full privacy policy](privacy.html)

## Footer

### Line 1 [footer.line1]
> **ParishFinder** — Mass times for the Diocese of Cleveland

### Line 2 [footer.line2]
> A personal project of Fr. Michael Garvin. Not an official function or arm of the Roman Catholic Diocese of Cleveland.

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
> Last updated 1 August 2026

### Lead paragraph [pp.lead]
> ParishFinder has no accounts, no advertising, and no analytics or tracking. It does not build a profile of you, and it never sells or shares personal information. The only information that leaves your device is what you deliberately submit through the feedback form.

### Who runs it [pp.operator]
> ParishFinder is a personal project of Fr. Michael Garvin, and is not an official function or arm of the Roman Catholic Diocese of Cleveland. “We” and “us” below mean him. It covers parishes across the Diocese of Cleveland.

## Information the app handles

### Heading [pp.handles.h2]
> Information the app handles

### Location heading [pp.location.h3]
> Location

### Location paragraph 1 [pp.location.p1]
> If you use the Map tab and grant location permission, the app reads your device's approximate or precise location. Your location is used **only on your device**, to center the map near you and to sort parishes by distance. It is **not transmitted to us**, not stored after the screen is closed, and not shared with anyone.

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
> Mass, confession, and adoration times are compiled from publicly available parish bulletins and websites. They can change without notice, particularly around holy days and holidays. ParishFinder makes no guarantee of accuracy — please confirm with the parish directly before traveling.

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

- **The parish count appears twice** — the hero lede and the big number — and
  the two must move together. It is deliberately the floor **"180+"**, not an
  exact figure (changed from 184 on 2026-08-06): the count of *parishes* versus
  *worship sites* is easy to conflate, and a floor stays true as the dataset
  shifts. `docs/play-listing.md` uses the same figure and carries the reasoning;
  change both or neither.

- **The privacy claims are load-bearing.** Statements like "your location never
  leaves your phone" and "no analytics" are what the app was built to be able to
  say, and Play's Data Safety form is filled out to match. If you soften or
  strengthen any of them, `docs/play-data-safety.md` needs to agree.

- **The launch badge is a placeholder.** "Coming soon to Google Play and the
  Apple App Store" needs replacing with real store badges and links once the
  listings are live. There is deliberately no waiting list and no CTA button.
