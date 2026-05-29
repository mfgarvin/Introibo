# `export.json` Shape Changes — for the Introibo App

This is a **breaking** change to `export.json`. The scraper now emits fully
structured schedules instead of display strings. The app no longer needs
`schedule_parser.dart` (or any regex parsing of schedule lines) — every field
arrives pre-parsed.

## Old shape (deprecated)

```json
{
  "name": "St. Sebastian Parish",
  "parish_id": "0689",
  "address": "476 Mull Ave",
  "city": "Akron, OH",
  "zip_code": "44320",
  "phone": "330-836-2233",
  "website": "https://www.stsebastian.org",
  "lonlat": "-81.5446,41.0780",
  "bulletin_url": "...",
  "timestamp": "2026-05-27",
  "mass_times":  ["Sunday: 9:00AM, 11:00AM (Spanish)", "Saturday: 4:30PM - Vigil Mass"],
  "confessions": ["Saturday: 3:00PM to 3:30PM"],
  "adoration":   ["Perpetual Adoration (24/7)"],
  "events_summary": "..."
}
```

## New shape

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
  "bulletin_url": "...",
  "timestamp": "2026-05-27",
  "schedules": {
    "mass": [
      {"day": "Sunday",   "start": "09:00", "mass_date": null,         "language": null,      "notes": null},
      {"day": "Sunday",   "start": "11:00", "mass_date": null,         "language": "Spanish", "notes": null},
      {"day": "Saturday", "start": "16:30", "mass_date": null,         "language": null,      "notes": "Vigil Mass"},
      {"day": "Wednesday","start": "16:00", "mass_date": "2025-12-24", "language": null,      "notes": "Christmas Eve Vigil"},
      {"day": "Wednesday","start": "00:00", "mass_date": "2025-12-25", "language": null,      "notes": "Midnight Mass"}
    ],
    "confession": [
      {"day": "Saturday", "start": "15:00", "end": "15:30", "notes": null}
    ],
    "adoration": {
      "is_perpetual": true,
      "times": []
    },
  },
  "events_summary": "..."
}
```

## What changed

| Old | New | Notes |
|---|---|---|
| `mass_times: string[]` | `schedules.mass: object[]` | Each entry has `day`, `start` (HH:MM), `mass_date`, `language`, `notes` |
| `confessions: string[]` | `schedules.confession: object[]` | `day`, `start`, `end`, `notes` |
| `adoration: string[]` | `schedules.adoration: {is_perpetual, times}` | `times: [{day, start, end, notes}]`. `is_perpetual: true` means 24/7; render once, don't enumerate `times` (will be empty) |
| `lonlat: "lon,lat"` | `latitude: float`, `longitude: float` | Both null when no coords; the old comma-string is gone |

## Field-by-field

### `schedules.mass`

- **`day`**: full English weekday (`"Sunday"` … `"Saturday"`)
- **`start`**: `"HH:MM"` 24-hour, zero-padded (`"09:00"`, `"16:30"`)
- **`mass_date`**: `null` for regular weekly Mass; ISO `"YYYY-MM-DD"` for holiday / one-off Masses (Christmas, Easter, Holy Days, etc.)
- **`language`**: null = English; otherwise free-text (`"Spanish"`, `"Latin"`, `"Vietnamese"`, etc.)
- **`notes`**: optional free text (`"Vigil Mass"`, `"Christmas Eve"`, `"First Friday only"`)

Entries are pre-sorted: by `mass_date` (regular masses first, holidays after), then by weekday, then by start time.

### Holiday Mass handling

Regular weekly Mass → `mass_date: null`. Always show.

Holiday Mass → `mass_date: "YYYY-MM-DD"`. Show only when the date is upcoming
(suggested window: today through +7 days). Hide after the date passes. The
`day` field still reflects the day of week the date falls on, so a Mass on
Christmas Day 2025 has `day: "Thursday"` and `mass_date: "2025-12-25"`.

This is the headline reason for the rewrite — holiday Masses were silently
dropped by the old string formatter.

### `schedules.confession` and `schedules.adoration.times`

Same shape: `{day, start, end, notes}`. Both `start` and `end` are `"HH:MM"`.

### `schedules.adoration`

```json
{ "is_perpetual": false, "times": [{"day": "Tuesday", "start": "08:30", "end": "19:40", "notes": null}] }
```

Or for perpetual:

```json
{ "is_perpetual": true, "times": [] }
```

If `is_perpetual: true`, render a single "Perpetual Adoration" card and skip
the times array (it'll be empty). Otherwise enumerate `times` like confessions.

### `latitude` / `longitude`

Plain floats. Either may be `null` if the parish has no geocoded address.
The old `lonlat` comma-string is removed.

### Unchanged

- `name`, `parish_id`, `address`, `city`, `zip_code`, `phone`, `website`,
  `bulletin_url`, `timestamp`, `events_summary` all unchanged.

## Migration steps for Introibo

1. Update `Parish.fromJson` in `lib/models/parish.dart`:
   - Read `latitude` / `longitude` as nullable doubles; drop `lonlat` parsing.
   - Read `schedules.mass`, `schedules.confession`, `schedules.adoration` as
     structured lists/objects instead of `List<String>`.
2. Delete `lib/utils/schedule_parser.dart` and its callers — all data arrives pre-parsed.
3. Add a filter in the Mass schedule view: hide entries whose `mass_date` is
   non-null and in the past; visually flag entries whose `mass_date` is non-null
   and within the next 7 days as "Special / Holiday Mass" using the `notes` text.
4. Adoration view: branch on `is_perpetual` before rendering.
5. Drop the legacy `www` key tolerance — the scraper has only emitted
   `website` for a while.

## Not yet addressed (future work)

These were suggestions in the original notes that are deferred:

- **Per-section timestamps** (`timestamps.mass_times`, `timestamps.confessions`, …) — would require diff-tracking in the Notion sync layer. Not done.
- **Structured `events` list** (separate from `events_summary` prose) — the underlying extraction already produces structured events; they're just not exported yet. Easy follow-up if the app wants them.
- **PDF-vs-extracted discrepancy detection** — out of scope.
