# Play Store listing

Draft copy and asset specs for the ParishFinder listing. Everything here is a
starting point — read it in your own voice before publishing.

---

## App name (30 char max)

```
ParishFinder
```
*12 characters.* If you want keyword reach and the name is unclaimed:
`ParishFinder: Mass Times` (24 characters).

> Check availability first — "ParishFinder" is a fairly generic name and
> similar apps exist. A confusingly similar name to an existing app is grounds
> for rejection.

## Tagline

**Discover the Life of the Church**

Used on parishfinder.app and as the subtitle under the app title on the Home
screen. It deliberately does *not* appear as the Play short description — see
below.

## Short description (80 char max)

```
Catholic Mass, confession & adoration times across the Diocese of Cleveland.
```
*76 characters.*

> Resist putting the tagline here. This field is the single biggest lever on
> Play search ranking, and "Discover the Life of the Church" contains none of
> the words people actually type — *Mass times*, *confession*, *adoration*,
> *Cleveland*. The tagline sets the tone where someone has already arrived; the
> short description has to get them there.
>
> Says **Diocese of Cleveland**, not "Cleveland and Akron", to match the site —
> see the coverage note under the full description.

## Full description (4000 char max)

```
Discover the Life of the Church across the Diocese of Cleveland.

ParishFinder is a free app that brings together Masses, confession, and
adoration for 180+ Catholic parishes across the 8 counties of the Diocese of
Cleveland — each schedule pulled from the parish bulletin, the most up-to-date
resource a parish has, so you don't have to hunt through them.

WHAT'S THE NEXT MASS?
Open the app and see the next Mass starting near you, with the parish, the time,
and how long you have to get there. No searching required.

PARISHES NEAR YOU
New to the area? Look at a map of what's around you. Swipe the carousel for
schedules, or tap a marker for the full parish page.

SEARCH BY NAME, CITY, OR ZIP
Looking for a specific parish? Search by name, city, or ZIP code. The search
understands how people actually type — "St", "St.", "Saint", and "Sts" all find
what you mean.

CONFESSION & ADORATION
Whether you're planning ahead or the Spirit is moving you now, find where
confession and adoration are being offered — sorted by distance or by what's
happening soonest. Perpetual adoration chapels are marked.

EVERYTHING A PARISH PAGE SHOULD HAVE
Full Mass schedules with vigils and language noted, confession windows,
adoration times, address with one-tap directions, phone, website, and a link to
the latest bulletin.

YOUR HOME PARISHES
Keep the parishes you call home easily accessible, one tap away.

THE LITURGICAL DAY
Wondering what orations will be used? See today's feast, saint, or season at a
glance.

IT WORKS OFFLINE
Schedules are cached on your phone — after setting it up once, it'll work
anywhere, even in the parish hall that has absolutely no reception.

HELP KEEP IT ACCURATE
Times change, especially around the holidays or holy days. Every parish page
lets you confirm the information or report what's wrong, crowdsourcing any
changes that need to be made. And if we can't verify a parish's schedule, we'll
let you know.

NO ADS. NO ACCOUNTS. NO TRACKING.
No advertising, no sign-up, no profile, no analytics — and it's totally free.
Your location never leaves your phone: it's used on the device to center the map
and sort by distance, and is never transmitted or stored.

---

Mass, confession, and adoration times are compiled from publicly available
parish bulletins and websites. They can change without notice, particularly
around holy days and holidays. Please confirm with the parish directly before
traveling.

ParishFinder is a personal project of Fr. Michael Garvin. It is not an official
function or arm of the Roman Catholic Diocese of Cleveland.

Map data © OpenStreetMap contributors.
```

> **The count is deliberately "180+"**, not an exact figure. The 2026-08-04
> snapshot has 189 records with 189 distinct name+city pairs and 189 distinct
> addresses — no repeated `parish_id` at all (183 records carry an id, 6 carry
> none). The older "184 parishes" number isn't derivable from that data, and
> parishes/worship sites are easy to conflate, so a floor that stays true as the
> data shifts beats a precise number that quietly goes stale. Re-check the
> disclaimer line too — you should state plainly that you are not affiliated
> with the diocese, since the app covers its parishes.
>
> The landing page (`site/index.html` + `site/CONTENT.md`, twice each) and
> `docs/QA_SPEC.md` were brought to "180+" on 2026-08-06 to match. `CLAUDE.md`
> still describes the dataset as "189 records across 184 parishes" — an internal
> note, not public copy, but it doesn't hold against the current snapshot.

> **Coverage is stated as the Diocese of Cleveland**, aligned to the site
> (2026-08-06). This listing previously said "Greater Cleveland and Akron",
> which the site never says — `site/index.html` uses "Diocese of Cleveland"
> seven times, plus "Northeast Ohio" and "the 8 counties". The site's framing is
> also the one the data supports: the 2026-08-04 snapshot spans 96 cities and
> ZIP prefixes 440–443, 446, and 448, so it reaches well past the two metros.
> Keep the two in step — a listing that claims narrower coverage than the site
> reads as two different products.

---

## Graphics required

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit, no alpha | **Ready** — `docs/store/play-icon-512.png` |
| Feature graphic | 1024×500 PNG/JPG, no alpha | **Ready** — `docs/store/play-feature-graphic-1024x500.png` |
| Phone screenshots | 2–8 images, 16:9 or 9:16, min 320 px, max 3840 px | **Missing** |
| 7" tablet screenshots | Optional | — |
| 10" tablet screenshots | Optional | — |

Both store graphics, the launcher icons in `android/app/src/main/res/mipmap-*/`,
the iOS app icon set, the web PWA icons, and the marketing site's favicon are all
generated by **`tool/gen_icons.py`** from the vector source in the Design handoff
bundle. Never hand-edit those PNGs — change the script (or the palette constant at
its top) and re-run it. `python3 tool/gen_icons.py --check` fails if any committed
asset has drifted from what the script produces.

### Screenshot plan

Play shows the first two screenshots in search results, so lead with the
strongest. Suggested order:

1. **Home** with the next-Mass banner populated — the one-glance value.
2. **Map** with parish markers and the carousel visible.
3. **Parish detail** showing a full Mass schedule.
4. **Confession or adoration** filtered list.
5. **Liturgical day** tile / home in dark mode — shows the theme off.

Capture on a device with a clean status bar. Consider framing them with a short
caption band over each, since text in screenshots is what most people actually
read.

### Icon

Shipped, in the **`sacred-scarlet`** palette. A gold-glass church roundel — cross
finial, spire, rose window, arched door — standing on green ground under a cream
sky, ringed by heavy lead came and a lighter iron armature ring, on a deep scarlet
field with a faint diaper lattice. It comes from the app's stained-glass
vocabulary and sits close to the app's own oxblood (`#8C1F1F`).

Unlike the other palettes, `sacred-scarlet` gives the roundel its own sky and
ground colours instead of tinting them from the field — that cream sky is what
keeps the gold church legible down to 48 px against a red surround.

The handoff also carries `sapphire-vigil`, `martyr-crimson`, and `doctor-amber` —
switch by changing `PALETTE` in `tool/gen_icons.py` and re-running it.

The handoff's exports disagree on how large to draw the mark. Measured against the
area a user actually sees, its Android foreground fills ~82% of the tile, its
store-listing export ~55%, and its iOS export ~45% — the same roundel at three
sizes. The script normalizes everything to the Android framing, so the icon is the
same size on every platform.

The Play **feature graphic** is a deliberately richer composition than the icon —
it keeps the corner fleurons and a smaller roundel, which the handoff describes as
"the full parish-window treatment … the system the icon simplifies from."

---

## Categorization

- **App category:** Lifestyle — **settled 2026-08-06.**
  *(Books & Reference and Travel & Local were the alternatives considered.)*
- **Tags:** choose up to 5 — Religion, Local, Maps & Navigation
- **Contact email:** contact@parishfinder.app
- **Website:** https://parishfinder.app
- **Privacy policy:** https://parishfinder.app/privacy *(must be live before
  submission)*

## Countries

Start with the **United States** only. The data covers one Ohio metro area;
there is no reason to surface it worldwide, and a narrow release keeps early
reviews from people who can actually use the app.
