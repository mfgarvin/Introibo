# Bulletin Scraper — Notes from the Introibo App Side

This document is intended to be handed to whatever is maintaining the
[bulletin scraper](https://github.com/mfgarvin/bulletin) that produces
`export.json`. It captures concrete data-quality observations made while
building the Introibo Flutter app, and recommends a JSON shape that the app
can consume without lossy heuristics.

The app currently pulls from:
`https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json`

## Field-by-field observations & recommendations

### `mass_times`, `confessions`, `adoration` (lists of strings)

The app parses these with `lib/utils/schedule_parser.dart`. Two problems
showed up that the parser had to work around:

#### 1. Time ranges showed as duplicates (now fixed app-side)

Some strings looked like:

```text
"Tuesday: 3:00PM to 3:30PM"
"Saturday: 9:30AM to 10:00AM"
```

The old parser regex-matched both `3:00PM` and `3:30PM` separately, so the
timeline rendered two rows: "3:00 PM" and "3:30 PM". As of this commit the
parser detects `to`/`until`/`through`/`-`/`–`/`—` connectors and emits one
entry with start + end. **This works, but it's fragile** — if the scraper
ever emits, say, `"3:00PM-3:30PM, 7:00PM"`, the parser handles it; but if
it emits `"3:00PM and 3:30PM"` as a literal range, the app will treat them
as two separate confessions again.

**Recommendation:** scrape into a structured form. Either:

a) **Preferred — emit structured entries directly:**

```json
"confessions": [
  {
    "day": "Saturday",
    "start": "15:00",
    "end":   "15:30",
    "note":  null
  },
  {
    "day": "Tuesday",
    "start": "19:00",
    "end":   "19:30"
  }
]
```

`day` is the canonical English name; `start`/`end` are 24-hour `HH:MM`.
`note` is for human-only annotations like "Vigil Mass" or "Spanish" that
the app shows in muted text.

b) **Or — if you must keep flat strings, standardize the format** to a
single canonical pattern: `"<Day>: <HH:MMam/pm>(–<HH:MMam/pm>) [- note]"`.
Use the en-dash `–` (not `to`, not `-`) for ranges. The app will parse
either, but the structured form removes guesswork from future readers.

#### 2. Vigil / language / annotation notes are inconsistent

Examples encountered:

```text
"Saturday: 4:30PM - Vigil Mass"
"Sunday: 12:30PM (Spanish)"
"Sunday: 1:00 PM Spanish"
```

The app strips notes by looking for ` - <something>` (with surrounding
spaces). Variations with parens, no space, or comma-prefix annotations
are not extracted, so the user sees them stuck onto the time itself.

**Recommendation:** put non-time annotations into a separate `note` field
in the structured form, or *always* use the `" - "` separator if keeping
strings.

#### 3. Adoration ranges that span hours

Adoration often runs many hours: `"Tuesday: 8:30AM to 7:40PM"`. The app
handles this correctly now (single entry with start + end). However, some
parishes have continuous/perpetual adoration that doesn't fit a daily
schedule. Today the data either omits these or shoehorns them into one
entry. Consider an explicit shape:

```json
"adoration": [
  { "type": "perpetual" },
  { "day": "Tuesday", "start": "08:30", "end": "19:40" }
]
```

The app would render "Perpetual adoration" as a single card and skip
timeline grouping for it.

### `lonlat`

Format observed: `"-81.4749273,41.5212583"` (longitude first, comma,
latitude). The model parses this in `lib/models/parish.dart`. 188/189
parishes have coords; the one missing breaks the map marker for that
parish.

**Recommendation:** always emit lat/lon. If a parish address can't be
geocoded, log it loudly in the scraper rather than silently emitting
nothing — that way the missing parish is visible upstream.

Consider switching to plain `latitude`/`longitude` numeric fields. The
combined string is harder to consume and easy to invert by mistake.

### `bulletin_url`

Currently optional. The detail page only shows the "Weekly Bulletin"
button when present. One observation: the user noted that the **content
of the bulletin sometimes doesn't match the parish's stated mass times**.
That's not something Introibo can fix — but the scraper should consider
re-running parses on a regular cadence and surfacing discrepancies (e.g.,
times in the bulletin PDF that don't match `mass_times`) for manual review.

### `timestamp`

Format observed: `"YYYY-MM-DD"`. The app parses this with `DateTime.tryParse`
and shows it as "Data last updated: MM-DD-YY" on each parish detail page.
This works. Consider including a per-field timestamp if you do partial
re-scrapes, e.g. `"timestamps": {"mass_times": "2026-05-01", "confessions":
"2026-04-22"}` — the app could surface "Mass times verified 3 weeks ago"
which is more honest than an aggregate.

### `website`

Two legacy keys are tolerated: `website` (new) and `www` (old). The model
prefers `website`. **Recommend:** drop `www` everywhere on the next scrape
to remove the fallback path.

### `events_summary`

Free-text prose paragraph. The detail page renders it as-is. No issues
observed beyond occasional length variability. Consider:

- Cap at ~500 chars in the scraper, or
- Split into `[{title, date, summary}]` structured events so the app can
  build a small "Upcoming events" list view.

The latter is a bigger lift but would let Introibo wire up the "Parish
Events" quick-access button on the home page, which is currently a
"Coming Soon" placeholder.

## Suggested target JSON shape

For a clean future:

```json
{
  "name": "St. Sebastian Parish",
  "parish_id": "0689",
  "address": "476 Mull Ave",
  "city": "Akron, OH",
  "zip_code": "44320",
  "phone": "330-836-2233",
  "website": "https://www.stsebastian.org",
  "latitude": 41.0780,
  "longitude": -81.5446,
  "image_url": null,
  "bulletin_url": "...",
  "timestamps": {
    "scraped":      "2026-05-27",
    "mass_times":   "2026-05-27",
    "confessions":  "2026-05-20"
  },
  "schedules": {
    "mass": [
      { "day": "Sunday",   "start": "09:00", "note": null },
      { "day": "Sunday",   "start": "11:00", "note": null },
      { "day": "Saturday", "start": "16:30", "note": "Vigil Mass" }
    ],
    "confession": [
      { "day": "Tuesday",  "start": "19:00", "end": "19:30" },
      { "day": "Saturday", "start": "09:30", "end": "10:00" }
    ],
    "adoration": [
      { "day": "Tuesday",  "start": "08:30", "end": "19:40" }
    ]
  },
  "events_summary": "..."
}
```

If you adopt this, the Introibo `Parish.fromJson` factory in
`lib/models/parish.dart` will need a parallel update (the schedule parser
can be bypassed — entries arrive pre-parsed), and that's a worthwhile
trade for ridding the codebase of regex-based schedule scraping.

## TL;DR for the scraper rewrite

1. **Emit structured `{day, start, end, note}` entries** instead of free
   strings.
2. **Always use 24-hour `HH:MM`** for times; no AM/PM ambiguity.
3. **Use ISO day names** (`Monday`–`Sunday`), not abbreviations.
4. **Pull annotations** (Vigil, Spanish, Latin, etc.) into a `note` field.
5. **Emit `latitude`/`longitude` numerics**, retire the `lonlat` string.
6. **Per-section timestamps** so we can show data freshness honestly.
7. **Bulletin discrepancy detection**: log mismatches between PDF content
   and stated times, surface for manual review — but don't try to fix
   them silently.
