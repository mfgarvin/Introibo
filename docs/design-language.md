# ParishFinder — Design Language

A self-contained brief for designing app icons and other visual assets. No repo
access needed; every value below is transcribed from the shipping app.

---

## 1. What the app is

ParishFinder is a Flutter mobile app for finding Catholic parishes and Mass times
in the Cleveland/Akron area of Ohio. Two things people do with it: look up a
specific parish, or find one near them right now. The most common real-world use
is someone standing outside on a Saturday afternoon asking "where can I still
make a Mass today?"

Audience: ordinary Catholic laypeople, wide age range, often in a hurry. It is a
devotional-adjacent utility, not a devotional app — it should feel reverent but
it must never feel like it's slowing you down.

## 2. Design thesis

**Sacred architecture, rendered as a calm utility.**

The visual language borrows from Gothic parish churches — stained glass,
parchment, oxblood and gold, an old-style serif — but applies it with restraint,
on top of a plain, fast, modern app skeleton. Warmth and craft in the surfaces;
clarity and speed in the structure.

Three words: **warm, reverent, unfussy.**

Explicitly *not*: clip-art piety, glossy skeuomorphism, dark medieval fantasy,
corporate SaaS blue, or anything jokey.

## 3. Color

Two full themes. Light is the primary identity; dark is a true-black OLED mode
where gold becomes the dominant accent.

### Light — warm parchment + oxblood + gold

| Role | Hex | Notes |
|---|---|---|
| Background | `#FAF6EE` | Warm cream parchment. The signature surface. |
| Card surface | `#FFFCF4` | Barely-warm white, sits just above the parchment. |
| Primary accent | `#8C1F1F` | Deep oxblood. The dominant accent in light mode. |
| Secondary | `#4A2828` | Deep plum — headings, secondary accents. |
| Gold (ornament) | `#C9A227` | Rich gold. **Ornament and icons only** — fails AA as text on cream. |
| Gold (text-safe) | `#8C5A14` | Deep bronze-gold, ~5.2:1 on parchment. Use when gold must be *read*. |
| Text | `#2A1B1B` | Warm near-black. Never pure `#000`. |

### Dark — true black + candlelight

| Role | Hex | Notes |
|---|---|---|
| Background | `#000000` | True black, chosen for OLED. |
| Card surface | `#14100F` | Warm-toned near-black — warmth is preserved, not neutralized. |
| Primary accent | `#D4A24A` | Candlelight gold. Replaces oxblood, which disappears against black. |
| Text | `#F4E9D8` | Warm cream. |

**The rule that matters:** in light mode the app leans red; in dark mode it leans
gold. Reds are never used as accents on black, and bright gold is never used as
body text on cream.

### Liturgical colors

Used only in the liturgical-day tile, following the Roman calendar. Keep these
recognizable rather than restyled: Violet `#6A1B9A`, White `#E6D9A8`, Red
`#C62828`, Rose `#E57399`, Green `#2E7D32`, Black `#37474F`.

## 4. Typography

Two families, strictly divided by job:

- **Cormorant Garamond** — display, headings, parish names, the app title. High
  contrast, old-style serif. This is the voice of the app. Weights 600–700.
- **Inter** — body, labels, captions, time chips, everything functional. It stays
  out of the way. Weights 400–700.

Scale in use: display 32 · title 28 / 22 · body-large 15 · body 14 · caption 12 ·
label 12 (bold) · kicker 10 (all-caps, `letter-spacing: 1.3`).

The kicker style — tiny, bold, wide-tracked, all-caps Inter ("NEXT MASS NEARBY",
"TONIGHT") — is a recurring signature and worth echoing in marketing assets.

## 5. The signature motif: the parish window

**This is the strongest visual cue in the app, and the most promising basis for
an icon.**

Every parish is given its own stained-glass "window," generated deterministically
from its ID. It appears as a small rounded chip in lists and full-bleed as the
parish detail page header, and the chip flies into the header on navigation.
Users learn parishes by their window.

The construction is a **Chartres armature panel** — a medallion held in an iron
frame against a deep field:

1. A **deep field** of a single glass tone, crossed by a faint diagonal **diaper**
   lattice at about 7% white — the ghost of a leaded quarry, not a full one.
2. A **quatrefoil fleuron** tucked into each corner: four small circles arranged
   around a point. Dropped below 70px, where they only add noise.
3. A central **roundel**: eight wedges of alternating glass around a small bright
   hub, ringed by heavy lead came.
4. A lighter **iron armature ring** outside the came, at roughly half its weight —
   the two concentric rings are a hierarchy, not a double border.

Two rules the geometry must obey, both learned by getting them wrong first:

- **Nothing rotates randomly.** The roundel's wedges are offset by half a wedge so
  that a *pane of glass* sits on the vertical, not a lead line. The four wedges
  sharing the accent colour then land on the four axes and read as an upright
  cross. An earlier version started the wedges at a random angle per parish and
  the result looked tilted and careless.
- **Every size is composed, not cropped.** The artwork is drawn for whatever box
  it is given, and line weights scale with that box. A 44px chip is not a
  centre-crop of a wide header.

Restraint is the point. An earlier pass jittered every vertex and scattered hue by
±14° per pane; it read as busy rather than made. Per-pane variation is now ±3°
hue, ±3% saturation, ±3.5% lightness — enough to feel handmade, not enough to
fracture the palette.

## 5a. Colour is inferred from the patron

A parish's palette is not random. Its **name** is read for what it is named after,
and that chooses the colour:

- **Family** — the hue. Nine of them: Marian (blues), martyr (crimsons), apostolic
  (indigo and sea), doctor (ambers and golds), religious (greens and earths),
  luminous (Christological white-golds), spirit (flame), contemplative (violets),
  angelic (pearl and silver).
- **Member** — which of the three or four palettes in that family. Where the
  patron carries a national tradition — an Irish monk, a Polish martyr, an Italian
  friar — the palettes suited to it are preferred.

28 palettes in total, **12 of them pale**, so the range runs from Chartres blue to
a grisaille barely tinted at all. In a diocese of 189 parishes, 188 names resolve
to a patron; the one that doesn't is spread across the families by hash so it
never looks like a fallback.

Two consequences for any asset work:

- **The colour means something.** A Marian parish reads blue; a martyr reads red.
  Don't treat the palettes as interchangeable swatches.
- **A single brand asset needs a fixed palette**, since the per-parish variety
  doesn't apply. Use **Sapphire Vigil** — `#0B2A4A` · `#1E5F8A` · `#3A7CA5` ·
  `#C9A227` · `#E8D7A1` — the Marian blue-and-gold that reads most like the app.

## 6. Iconography

- Two custom SVGs carry the sacramental concepts: a **monstrance** (Eucharistic
  adoration) and a **confessional** (reconciliation). Simple, solid, single-color,
  tinted at runtime.
- Everything else is stock Material icons (clock, location pin, star, directions).
- Custom icons should read at 24px, work as a flat single-color silhouette, and
  sit visually alongside Material's weight — not heavier or more detailed.

## 7. Shape, depth, motion

- **Corner radius:** 12 is the default; 16 for cards, 20 for large containers,
  8–10 for small chips. Nothing is square-cornered; nothing is a pill except
  small badges.
- **Depth:** very soft, wide, low-opacity shadows (roughly 15px blur, 4px down,
  6% black). Elevation is a whisper. No hard drop shadows, no borders as the
  primary separator.
- **Motion:** restrained and physical. The one hero moment is a parish's glass
  chip flying in a straight line and growing into the full detail header, its
  corner radius and scrim easing in step. Nothing bounces, spins, or arcs.

## 8. What's needed

App icon and store assets. Deliverables:

- **Android adaptive icon** — separate foreground and background layers, 108×108dp
  canvas with the inner 72×72dp as the safe zone (the system may mask it to a
  circle, squircle, or rounded square, so nothing meaningful can approach the edge).
- **iOS app icon** — 1024×1024 master, square, no transparency, no pre-applied
  corner rounding.
- **Play Store / App Store listing art** and a feature graphic, if you're going
  that far.

Constraints worth designing around:

- It must survive being masked to a **circle** and shrunk to ~48px. The app has
  already solved this for itself: at chip sizes it drops the corner fleurons and
  leans on the **roundel**, which is a single legible shape. The icon should do
  the same — the roundel and its came, with the diaper field behind it, and the
  fleurons only if they still read.
- The icon lives on both light and dark home screens — it needs its own background,
  and it cannot rely on the parchment surface being there.
- No crosses-as-logo unless handled with real care; the stained-glass roundel is
  more distinctive and less generic than yet another cross app icon.
- The name is **ParishFinder** (one word, both capitals).

## 9. Do / don't

**Do**
- Keep surfaces warm — cream and bronze rather than white and grey.
- Let gold be ornament, and oxblood be the thing that carries meaning.
- Favor geometry that could plausibly be cut from glass and joined with lead.
- Assume a hurried user: legibility beats atmosphere every time they conflict.

**Don't**
- Use pure white, pure black (outside the OLED background), or cool greys.
- Put bright gold `#C9A227` on cream as text.
- Add gradients to type, drop shadows to icons, or ornament to functional UI.
- Reach for stock religious clip art, doves, or script fonts.
