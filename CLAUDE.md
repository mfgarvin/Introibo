# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ParishFinder is a Flutter mobile application for finding Catholic parishes and mass times in the Cleveland/Akron, Ohio area. It provides two main features:
1. **Research a Parish** - Search parishes by name, city, or ZIP code
2. **Find a Parish Near Me** - Interactive map showing nearby parishes using GPS

## Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Run static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/schedule_parser_test.dart  # Run a single test file

flutter run                  # Run on default device (Linux desktop in dev)
flutter run -d linux         # Run on Linux desktop
flutter run -d chrome        # Run in Chrome (requires Chrome installed)

flutter build apk            # Build Android APK
flutter build ios            # Build iOS (requires macOS)
flutter build linux          # Build Linux desktop
```

## Architecture

### Application Flow

```
main.dart (ParishFinderApp)
    └── RootShell (bottom NavigationBar over an IndexedStack — tabs keep state)
            ├── Home tab     → HomePage
            │                    ├── inline search → ParishDetailPage
            │                    ├── "Looking for" quick filters → FilteredParishListPage → ParishDetailPage
            │                    ├── nearby / next-mass tiles → ParishDetailPage
            │                    └── liturgical day tile
            ├── Map tab      → FindParishNearMePage (inTab) → ParishDetailPage
            └── My Parishes  → FavoritesPage (inTab) → ParishDetailPage
```

`ResearchParishPage` still exists as a standalone search page but is no longer the
primary entry point — HomePage has inline search.

### Core Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, theme constants, `ThemeNotifier`, `FavoritesManager`, `RootShell` (bottom nav), `HomePage`, and the Settings/Feedback/About/Favorites pages |
| `lib/models/parish.dart` | `Parish` model with `fromJson`; schedules parsed into `ScheduleEntry` lists |
| `lib/services/parish_service.dart` | Remote JSON loader with local cache; global `parishService` singleton |
| `lib/utils/schedule_parser.dart` | Structured `ScheduleEntry` + occurrence math (schedule parser) |
| `lib/services/liturgical_service.dart` | Offline Computus baseline + best-effort calapi enrichment |
| `lib/services/feedback_client.dart` | POSTs feedback to the Cloudflare Worker endpoint |
| `lib/widgets/` | Stained-glass header, mass/timeline schedule cards, next-mass banner/tile, liturgical day tile, custom icons |

### Pages

| Page | Purpose |
|------|---------|
| `lib/pages/parish_detail_page.dart` | Full parish detail: header, schedules, contact, bulletin, feedback |
| `lib/pages/filtered_parish_list_page.dart` | Mass/Confession/Adoration filtered lists with sort + day/time filters |
| `lib/pages/find_parish_near_me_page.dart` | OSM map (Map tab) with GPS, markers, and a swipeable parish carousel |
| `lib/pages/research_parish_page.dart` | Standalone search UI (debounced; name/city/zip) |

### Data Flow

All pages read from the global `parishService` singleton
(`lib/services/parish_service.dart`), which loads cache-then-network:

1. Instant: last-good JSON from SharedPreferences (may be stale → offline warning).
2. Authoritative: fetched from the remote `export.json`, then cached.

```dart
static const _remoteUrl =
    'https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json';
```

The bundled `data/parishes.json` asset is no longer shipped — first launch requires a
network connection (an "Internet Required" screen handles that case). Use the local
`export.demo.json` (new shape, 189 parishes) for inspection.

### Data Model

`Parish` (`lib/models/parish.dart`) fields:
- `name`, `address`, `city`, `zipCode`, `phone`, `website`
- `parishId` — optional unique identifier
- `massTimes`, `confTimes`, `adoration` — `List<ScheduleEntry>` (pre-parsed; nothing downstream parses schedule strings)
- `adorationIsPerpetual: bool` + `hasAdoration` getter
- `bulletinUrl`, `eventsSummary`, `imageUrl`, `contactInfo` — optional
- `latitude`, `longitude` — nullable plain floats (now present in the data)
- `lastUpdated` — parsed from the per-record `timestamp`

JSON comes from the **structured** `export.json` shape:
- `schedules.mass[]`: `{day, start "HH:MM", mass_date, language, notes}`
- `schedules.confession[]`: `{day, start, end, notes}`
- `schedules.adoration`: `{is_perpetual, times: [{day, start, end, notes}]}`
- plain numeric `latitude`/`longitude`, plus `bulletin_url`, `timestamp`
- Legacy keys (`mass_times`, `confessions`, `conf_times`, `www`, `lonlat`) are gone.

### Key Dependencies

- `flutter_map` + `latlong2` — OpenStreetMap tile rendering and coordinates
- `geolocator` + `permission_handler` — GPS location with permission handling
- `google_fonts` — Inter (body) + Cormorant Garamond (display)
- `flutter_svg` — custom Catholic icons (monstrance, confessional)
- `http` — remote parish data, feedback, liturgy API
- `shared_preferences` — favorites + caches
- `url_launcher`, `cached_network_image`, `package_info_plus`

### Theme

Global constants in `main.dart` — **warm parchment + oxblood + gold** (light) /
**true black + candlelight gold** (dark):
- `kBackgroundColor`: `#FAF6EE` (warm cream parchment) · `kBackgroundColorDark`: `#000000` (OLED black)
- `kPrimaryColor`: `#8C1F1F` (deep oxblood) · `kSecondaryColor`: `#4A2828` (deep plum)
- `kAccentGold`: `#C9A227` (ornament only) · `kAccentGoldDeep`: `#8C5A14` (text-safe) · `kAccentCandlelight`: `#D4A24A` (dark-mode accent)
- `kCardColor`: `#FFFCF4` · `kCardColorDark`: `#14100F`
- Helpers `primaryAccentFor({isDark})` / `goldTextAccentFor({isDark})` — gold is too low-contrast as text on parchment, so accent *text* routes through these.

Typography: a unified scale in `lib/theme/app_text.dart`. **Inter** for body/UI,
**Cormorant Garamond** for display (app title, headings, parish names). Prefer the
`AppText` scale over inline `GoogleFonts.x(fontSize: …)`.

## Development Notes

### Dev Location Override

In `lib/pages/find_parish_near_me_page.dart`, a mock location is used in debug builds to bypass GPS:

```dart
const LatLng? kDevLocation = kDebugMode
    ? LatLng(41.48, -81.78)  // Lakewood, OH
    : null;
```

- In debug mode (`flutter run`): uses mock location, skips Geolocator
- In release builds: uses real GPS
- To test with different locations: change the coordinates
- To test real GPS in debug: set `kDevLocation` to `null`

### OSM Tile Configuration

The map uses OpenStreetMap tiles without subdomains (per OSM guidelines):
```dart
urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
```

### Parish Data

Data is fetched at runtime from the remote `export.json` (189 parishes, Cleveland/Akron
area) — see Data Flow above. The **structured** shape (sample, abbreviated):
```json
{
  "name": "St. Sebastian Parish",
  "parish_id": "0689",
  "address": "476 Mull Ave",
  "city": "Akron",
  "zip_code": "44320",
  "phone": "330-836-2233",
  "website": "www.stsebastian.org",
  "latitude": 41.0915,
  "longitude": -81.5621,
  "bulletin_url": "https://…",
  "timestamp": "2026-05-20",
  "schedules": {
    "mass": [
      {"day": "sunday", "start": "09:00", "mass_date": null, "language": "en", "notes": null},
      {"day": "saturday", "start": "16:30", "mass_date": null, "language": "en", "notes": "Vigil"}
    ],
    "confession": [
      {"day": "tuesday", "start": "19:00", "end": "19:30", "notes": null}
    ],
    "adoration": {"is_perpetual": false, "times": [
      {"day": "tuesday", "start": "08:30", "end": "19:40", "notes": null}
    ]}
  }
}
```

**Note:** Coordinates are now present in the data (`latitude`/`longitude` as plain floats),
so the map and distance-based sorting work. The full structured shape and migration notes
live in `EXPORT_SHAPE_CHANGES.md`; `export.demo.json` is a local copy for inspection.

## Change History

Dated session-by-session change logs have been moved out of this file to keep it lean (it loads into context every session). See [`docs/session-history.md`](docs/session-history.md) for the full chronological record, including the `Future Enhancements` notes.

A few non-obvious facts from that history worth keeping in view here:

- **Schedule data is fully structured** (no regex string parsing). `Parish.massTimes`/`confTimes`/`adoration` are `List<ScheduleEntry>` built from `schedules.*` in the remote `export.json`. See `lib/utils/schedule_parser.dart`.
- **Liturgy tile** uses an offline Computus baseline (`LiturgicalService.localToday`) plus best-effort enrichment from calapi.inadiutorium.cz, which is reachable only over **plain HTTP** (its IPv4 refuses 443); Android cleartext is scoped to that domain in `res/xml/network_security_config.xml`.
- **Feedback Worker** (`worker/`) is **deployed** to Cloudflare at `https://introibo-feedback.mfgarvin.workers.dev` (D1-backed, account mfjgarvin@gmail.com). The Worker/URL/D1 keep the old `introibo-feedback` name on purpose (the shipped app points at it). `lib/config/feedback_endpoint.dart` defaults to `…/feedback`, so submissions are live; override per-build with `--dart-define=FEEDBACK_ENDPOINT=…`. Redeploy/inspect via `worker/README.md` (`wrangler deploy`, `wrangler d1 execute …`).
- **Feedback monitoring**: the Worker now serves a Basic-Auth admin dashboard at `/admin` (secret `ADMIN_PASSWORD`) and posts a **daily Discord digest** via `scheduled()` on a `[triggers] crons = ["0 12 * * *"]` Cron Trigger (~8am ET) to the `DISCORD_WEBHOOK_URL` secret (optional `DASHBOARD_URL` link). Trigger manually with `POST /admin/digest`. `worker/logs.sh` remains a CLI viewer but needs local `wrangler login`. Secrets are **not** in git — set via `wrangler secret put` before the digest/dashboard work.
- **Favorites/"Home Parishes"**: the user-facing label is "home parishes" but the SharedPreferences key (`favorite_parishes`) and class names (`FavoritesManager`/`FavoritesPage`) were deliberately left unchanged to preserve existing saves.
- **Build number** is git-derived (`git rev-list --count HEAD`) on both platforms: Android via `gitBuildNumber` in `android/app/build.gradle`; iOS via a "Set Build Number From Git" Xcode Run Script phase that rewrites `CFBundleVersion` (added to `ios/Runner.xcodeproj/project.pbxproj`, **untested on a Mac** as of 2026-07-16). Both fall back to the pubspec/Flutter build number when git is unavailable.
- **iOS cleartext**: the liturgy API's plain-HTTP exception is scoped in `ios/Runner/Info.plist` via `NSAppTransportSecurity → NSExceptionDomains` (`calapi.inadiutorium.cz`), mirroring the Android `network_security_config.xml`. Location usage strings are also present; bundle id + signing + app icons still need a Mac.
