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

### Store badges [hero.badges]
> (not editable here — the official App Store and Google Play artwork)

> **The App Store badge is live** as of 2026-09-19, linking to Apple ID
> `6803622742`. The badge artwork is Apple's and Google's official files,
> self-hosted, and neither may be recoloured, cropped or redrawn — which is
> why they are images and not text you can edit here.

### "Coming soon to Google Play" note [hero.note]
> Coming soon to Google~Play

> The two stores did not go live together, so the hero does not either. iOS
> released 2026-09-18; the Play listing was still unpublished (its URL 404s)
> when this note went in. **This is a status note, not a control** — no button,
> no waiting list — and it is set deliberately quieter than the badge above it
> so it never reads as a second one.
>
> **The Play badge is already written**, directly above this note in
> `index.html`, fenced inside a comment marked `PLAY-OFF` / `PLAY-ON`. When
> Play publishes, it is two edits: delete those two fence lines, and delete
> this note. The Play URL needs no id — it is keyed on the application id
> `app.parishfinder`.

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

## Section: What it looks like

### Heading [shots.h2]
> What it looks like

### Intro [shots.intro]
> Easy to navigate and easily accessible, find the parish you're looking for and dive into what it offers in just a couple taps.

### Caption 1 [shots.home.caption]
> A simple, intuitive interface to find what you're looking for

### Caption 2 [shots.parish.caption]
> The life of the parish, at a glance

### Home screenshot alt text [shots.home.alt]
> ParishFinder's home screen on a phone: a Sunday banner, quick filters for Mass, Confession and Adoration, a search box, and the next Mass nearby at 11:00 AM.

### Parish screenshot alt text [shots.parish.alt]
> A ParishFinder parish page on a phone: a stained-glass header for the Cathedral of Saint John the Evangelist, the next Mass, address, bulletin link and the week's Mass times.

> **The alt text describes what is actually in the picture**, which means it
> goes stale if the screenshots are re-shot at a different time or place. The
> current pair were taken on a Sunday at 10:30 with the emulator placed in
> downtown Cleveland — hence the 11:00 AM Mass and the Cathedral.

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

### Footer link — help [footer.link.support]
> Help & FAQ

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
> Last updated 14 September 2026

> Bump this whenever the policy's *substance* changes — it is the date users and
> the stores read as "this is current". Changed 2026-09-14 to disclose the ZIP
> the app stores on the device.

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
> Location permission is optional. If you decline it, every other part of the app — search, parish details, schedules, home parishes — continues to work, and the app offers you a ZIP code instead (“Use a ZIP code” on the home screen, “Enter a ZIP code instead” on the map). A ZIP you type is matched against the parish directory already on your device to work out roughly where to centre the map and how to sort by distance; **no lookup service is contacted, and the ZIP is not sent to us**. It is saved on your device so you don't have to retype it, and clearing it — the “Near ZIP …” line on the home screen has a control for that — removes it. You can revoke location access at any time:

> The ZIP sentence is not decoration: the app really does persist what you type
> (`manual_location_zip`), and a policy that lists five stored things and not
> that one is wrong. If the ZIP fallback is ever removed from the app, remove it
> here and from the on-device list below.

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

### On-device item 3b — the ZIP [pp.device.item3b]
> A ZIP code you entered, if you used the ZIP-code option instead of location

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

# support.html

The help page, and the support URL on both store listings:
<https://parishfinder.app/support>.

**Every question is a collapsed row** (`<details>`) — the reader opens the one
they came for. So a *question* has to work as a summary line read on its own,
and an *answer* is what unfolds underneath. The first row is the only one that
starts open.

Every row also has an id, which is an anchor: a reply to someone's feedback can
link at `/support#not-supported` and land them on that answer, already open.
Ids are in brackets below — changing the wording is free, changing an id breaks
links already sent.

### Page title [sup.meta.title]
> Help & FAQ — ParishFinder

### Meta description [sup.meta.description]
> Help with the ParishFinder app: correcting a Mass time, which parishes are covered, using it without location or a signal, and how to reach Fr. Garvin.

### Heading [sup.h1]
> Help & FAQ

### Subheading [sup.updated]
> Support for the ParishFinder app

### Lead paragraph [sup.lead]
> I'm Fr. Michael Garvin. I built ParishFinder and I run it in my spare time — there is no support desk behind this page. Mail comes straight to me, and I'll read through it when I get the chance! For your convenience, I've answered some of the questions you might have already.

> **This page speaks in the first person, and the policy page doesn't.** That is
> deliberate: the privacy policy is a legal document and says "we", this is a
> priest answering his own users. Keep the "I" — it is the reason the page reads
> as though someone is behind it.

## Corrections

### Section heading [sup.corrections.h2]
> Corrections

### Q — wrong time [#wrong-times]
> A time in the app is wrong

### A — wrong time, intro [sup.wrong-times.intro]
> Tell me from inside the app, and I'll get a report. Easy as pie:

### A — wrong time, step 1 [sup.wrong-times.step1]
> Open that parish.

### A — wrong time, step 2 [sup.wrong-times.step2]
> Scroll to **“Is this information accurate?”** at the bottom of the page.

### A — wrong time, step 3 [sup.wrong-times.step3]
> Tap **Report an issue**, tick what is wrong — Mass times, confession, address, phone — and write what it should say.

### A — wrong time, step 4 [sup.wrong-times.step4]
> Leave your email only if you want an answer. It is the one optional field, and nothing else about you is sent.

### A — wrong time, what happens [sup.wrong-times.after]
> The report comes to me, not to the parish. I'll check it against that parish's current bulletin and correct the source data. That fix will reach everyone who uses the app — you don't have to update anything, and neither does anyone else.

> The quoted strings are the app's own: **“Is this information accurate?”** and
> **Report an issue** are what is printed on screen. If the app's wording
> changes, this has to follow, or the steps send people looking for a button
> that isn't there.

### Q — by email [#by-email]
> I'd rather write to you than use the form

### A — by email [sup.by-email.a]
> Sure! [contact@parishfinder.app](mailto:contact@parishfinder.app). Name the parish *and its city* — there are often multiple parishes with the same name, which can be confusing for me.

### Q — missing parish [#missing-parish]
> A parish is missing from the app

### A — missing parish [sup.missing-parish.a]
> Send me its name and city! It's possible I've missed it, but more often thann not, it's in a diocese that this app doesn't support yet. More on that below.

### Q — parish staff [#parish-staff]
> I work at a parish and our schedule has changed

### A — parish staff [sup.parish-staff.a]
> Cool! Let me know. Send the new schedule, or a link to the bulletin that carries it, and I will put it in. If your bulletin publisher has changed recently, tell me that too.

## Where I get this data from

### Section heading [sup.data.h2]
> Where I get this data from

### Q — the source [#source]
> What is any of this based on?

### A — the source, 1 [sup.source.p1]
> Parish bulletins — the primary thing a parish publishes every week and keeps current. Each parish's Mass, confession and adoration times are read out of its own most recent bulletin, along with its contact info. I'll give you a link to the bulletin, so you can read it for yourself, too!

### A — the source, 2 [sup.source.p2]
> Not from a website footer edited in 2019, and not from a diocesan directory. When a bulletin and a website disagree, the bulletin wins.

### Q — freshness [#freshness]
> How current is it?

### A — freshness, point 1 [sup.freshness.item1]
> Bulletins are re-read weekly, so corrections and seasonal changes land about weekly.

### A — freshness, point 2 [sup.freshness.item2]
> Your phone re-checks for new data **automatically**.

### A — freshness, point 3 [sup.freshness.item3]
> If a phone has failed to reach the data for **a week** (say, if you're offline), you'll get a warning. Just like if you were to read from last months' bulletin, it might not be completely accurate at that point!

### Q — unverified [#unverified]
> One parish says its times couldn't be confirmed

### A — unverified, 1 [sup.unverified.p1]
> That card — **“Do you know this parish?”** — means exactly what it says: For some reason, I couldn't confirm that schedule, and it might be wrong.

### A — unverified, 2 [sup.unverified.p2]
> If you attend there, let me know! **Confirm or correct the times** on that card takes about fifteen seconds and removes the doubt for everyone else.

> There is no need to list how many parishes might be unverified.

### Q — cancelled [#cancelled]
> A Mass is listed but it isn't happening this week

### A — cancelled [sup.cancelled.a]
> When a bulletin indicates that a Mass is cancelled, the app keeps that row on the schedule and strikes it through, with the reason the bulletin gave. It should be back in a week or two!

### Q — holy days [#holy-days]
> Holy days, Holy Week, funerals

### A — holy days, 1 [sup.holy-days.p1]
> This is something I'm still working on, and there could be issues here. Times move for Christmas, the Triduum and holy days of obligation, and a weekday Mass is sometimes given over to a funeral on two days' notice — which no bulletin printed in advance.

### A — holy days, 2 [sup.holy-days.p2]
> **On those days, it never hurts to call the the parish before you make the drive.** Though I try for this app to be as accurate as possible, sometimes that's impossible, and a little verification goes a long way.

## Which parishes are covered

### Section heading [sup.coverage.h2]
> Which parishes are covered

### Q — what's in it [#counties]
> What does the app actually contain?

### A — what's in it [sup.counties.a]
> Presently, every parish of the **Diocese of Cleveland** — 180+ of them, across its eight counties: **Ashland, Cuyahoga, Geauga, Lake, Lorain, Medina, Summit and Wayne**. A parish with more than one church gets an entry for each site, so you are given the address of the building the Mass is actually in.

### Q — out of diocese [#not-supported]
> It says my diocese isn't supported

### A — out of diocese, 1 [sup.not-supported.p1]
> You are outside those eight counties. The app still works — search, parish pages and schedules are all there — but you're technically outside of the service area, so these parishes might be quite a ways from you.  

### A — out of diocese, 2 [sup.not-supported.p2]
> This is based on the boundaries of the diocese. You might travel from one diocese to another routinely for Mass, which is fine! Some parishes in different dioceses might even be really close to each other. But technically, if you see this, the parishes closest to you, in your diocese, aren't included in this app. 

### Q — other dioceses [#other-dioceses]
> Will you cover my diocese?

### A — other dioceses, 1 [sup.other-dioceses.p1]
> I hope so! But, not right off the bat. There's a lot of legwork to get this setup, and I can't cover everything all at once.

### A — other dioceses, 2 [sup.other-dioceses.p2]
> If you want this app to support your diocese, let me know, but also tell your own parish priest and even your own diocesan offices! I'll leave it to the Spirit to help discern where this goes next.

## Using the app

### Section heading [sup.using.h2]
> Using the app

### Q — location [#location]
> Do I have to give it my location?

### A — location, 1 [sup.location.p1]
> No — However, if you decline, any of the location functions ("Nearest to me", your location on the map, etc.) either won't work or won't be super accurate. The core functionality will be there, but not everything.

### A — location, 2 [sup.location.p2]
> Instead, you can give it a ZIP code: **“Use a ZIP code”** on the home screen, **“Enter a ZIP code instead”** on the map. Type five digits and the app works out the centre of that ZIP from the parish list already on your phone — no lookup service is contacted and the ZIP is never sent to me. Distances are then measured from that centre, and the home screen shows *Near ZIP 44114* so you are never in doubt about which it used. Tapping that line clears it.

### A — location, 3 [sup.location.p3]
> When you do grant location, it is read on the phone and used on the phone. It is not transmitted, not stored, and not shared — see the [privacy policy](/privacy).

### Q — offline [#offline]
> Does it work without a signal?

### A — offline, 1 [sup.offline.p1]
> Yes, from the second launch onward. The first run downloads the parish directory and needs a connection to do so, but after that the whole directory lives on your phone. Schedules, search, parish pages and saved parishes all work with no signal whatever — in a church basement, in a hospital, on a plane. Now, it won't update if you stay offline, so I recommend using this online whenever possible

### A — offline, 2 [sup.offline.p2]
> Only three still need the internet: the map's tiles, opening a parish's actual bulletin, and staying up to date.

### Q — favourites [#favorites]
> How do I keep my own parish at hand?

### A — favourites [sup.favorites.a]
> Tap the star on its page. It joins **My Parishes**, the third tab, and it is then two taps from opening the app to reading this Sunday's times. Saved parishes stay on your phone.

### Q — dark mode [#dark-mode]
> Dark mode

### A — dark mode [sup.dark-mode.a]
> **Settings → Appearance → Theme.** Three choices: follow the phone, always light, always dark. A new install starts light. Pick *System* and it turns with your phone, including on a schedule.

### Q — liturgy tile [#liturgy]
> What is the tile with the feast day on it?

### A — liturgy tile [sup.liturgy.a]
> Today in the liturgical calendar — the season, its colour, and the saint or feast being kept. The app works the date out for itself, so it is right with no connection at all; when there is one, it fills in a few further details.

## The app itself

### Section heading [sup.about.h2]
> The app itself

### Q — cost [#cost]
> What does it cost, and who pays for it?

### A — cost, 1 [sup.cost.p1]
> It is free, with no advertising, no account, no subscription and no analytics watching you use it. I pay for the domain and the small server that hands out the parish data.

### A — cost, 2 [sup.cost.p2]
> I don't want to sell anything to you, nor do I want to sell your info to others! I built this to make it super easy to find what you're looking for at your local parish.

### A - cost, 3 [sup.cost.p3]
> That said, though, if you wish to donate to help me continue developing and running this app, I'd be greatly appreciative. Sent me an email if you wish to do that.

### Q — devices [#devices]
> Which phones does it run on?

### A — devices [sup.devices.a]
> **Android 7.0 or newer**, and **iPhone or iPad on iOS 15 or newer**. It is designed for a phone and lays itself out properly on a tablet.

> Both minimums are real settings, not marketing: Android's is Flutter's
> `minSdkVersion` (24), iOS's is `IPHONEOS_DEPLOYMENT_TARGET` (15.0) in the
> Xcode project. If either moves, this line moves with it.

### Q — official [#official]
> Is this from the diocese?

### A — official [sup.official.a]
> No. ParishFinder is my own project. It is not an official function or arm of the Roman Catholic Diocese of Cleveland, and neither the diocese nor any parish is answerable for what it shows — that is on me. The times in it are compiled from bulletins the parishes publish openly.

### Q — privacy [#privacy]
> What do you know about me?

### A — privacy, 1 [sup.privacy.p1]
> Only what you deliberately send. If you never submit feedback, nothing about you ever reaches me: there is no account, no analytics, and your location is used on your phone and stays there.

### A — privacy, 2 [sup.privacy.p2]
> A feedback submission carries what you wrote, which parish it was about, the app version, and your email if you chose to give one. You can have it deleted if you want — write to me with the parish and roughly when you sent it. The [privacy policy](/privacy) sets all of this out in full.

## Writing to me

### Section heading [sup.contact.h2]
> Writing to me

### Body 1 [sup.contact.p1]
> [contact@parishfinder.app](mailto:contact@parishfinder.app) — corrections, a missing parish, a question this page didn't answer, or something the app did that it plainly should not have. I'll do my best to read every message and answer as quickly as parish life allows.

### Body 2 [sup.contact.p2]
> If something in the app is broken rather than merely wrong, include the version from **Settings → About** and what phone you are on. That's super helpful for me, and it saves me from asking for it later.

---

# Things to know before editing

- **The contact address is `contact@parishfinder.app`** and now appears on
  every page — the landing page footer, the privacy policy, the support page
  (four times, including the two deep links people will actually use) and the
  404. It is also in the app itself and in `PRIVACY.md`. If you change it here,
  say so — it needs changing in all of those.

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

- **The hero carries one store badge and a note**, because iOS went live on
  2026-09-18 and Play had not. The Play badge waits behind the `PLAY-OFF` /
  `PLAY-ON` fence in `index.html` — see the note by `[hero.note]`. There is
  deliberately no waiting list and no CTA button beyond the badges themselves.

- **`support.html` is the store listings' support URL.** Both Apple and Google
  publish it beside the app, so it is the page a confused user actually lands
  on. Anything it says about how the app behaves — the ZIP fallback, the
  feedback prompt's wording, the OS minimums — has to stay true of the shipped
  app, the same way the privacy claims do.
