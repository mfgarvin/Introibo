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

## 5. The signature motif: generative stained glass

**This is the strongest visual cue in the app, and the most promising basis for
an icon.**

Every parish is given a unique, deterministic stained-glass "window," generated
from a seed derived from its ID. It appears as a small rounded chip in lists and
full-bleed as the parish detail page header, and the chip morphs into the header
during navigation. Users learn parishes by their window.

Construction, in order:

1. A **quarry tiling** of rhombic panes (taller than wide, ~0.78 aspect), laid in
   interlocking half-offset rows, with vertices lightly jittered so no two panes
   are identical — the geometry of a real Gothic quarry window, not a regular grid.
2. A circular **roundel / medallion** centered in the upper third, occupying about
   a quarter of the short dimension. Eight radial wedges alternating gold and a
   bright palette tone, around a small dark hub jewel. Panes are cut away where
   the roundel overlaps.
3. **Lead came** rendered as a near-black (`#050507`) stroke over every edge, with
   small filled dots stamped at vertices to suggest soldered joints, and a heavier
   ring around the roundel.
4. Each pane filled with a radial gradient (light corner → base → shadowed edge)
   so glass reads as lit from behind, plus a soft warm white glow from the upper
   left across the whole window.

Ten jewel-tone palettes rotate by seed — sapphire & gold, burgundy & rose, forest
& ember, vespers violet, twilight teal, emerald & copper, indigo & pearl, crimson
& saffron, midnight plum & rose-gold, slate & seafoam. Each is five stops:
`[deep, mid, bright, accent, highlight]`, with the accent (usually gold or amber)
dominating the roundel.

For a single fixed brand asset, **sapphire & gold** is the most representative:
`#0B2A4A` · `#1E5F8A` · `#3A7CA5` · `#C9A227` · `#E8D7A1`.

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

- It must survive being masked to a **circle** and shrunk to ~48px. The quarry
  tiling turns to mush at that size; the **roundel alone** is likely the right
  answer for the icon, with the tiling as texture at larger sizes only.
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
