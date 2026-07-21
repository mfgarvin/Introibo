# ParishFinder — QA Specsheet

> **Purpose.** A hand-off checklist for a lighter QA model (e.g. Haiku) to verify
> the app against its intended behavior. Each item is a concrete, checkable
> assertion. Mark each **PASS / FAIL / BLOCKED** and cite the file:line or the
> observed behavior. Do **not** assume — if you can't observe it, mark BLOCKED
> and say why.
>
> Source of truth for *intended* behavior: `CLAUDE.md`, `docs/session-history.md`,
> and the code paths cited below. Source of truth for *actual* behavior: run the
> app (see "How to run QA") or read the cited code.

---

## 0. Test environment & ground rules

| Fact | Value | Why it matters for QA |
|------|-------|----------------------|
| Real targets | Android + iOS (mobile) | This is a phone app; layout assumes a narrow portrait viewport. |
| Available dev device | **Linux desktop only** (`flutter devices` → `linux`) | Map GPS, Hero animation smoothness, and touch feel **cannot** be faithfully judged here. Flag anything device-specific as BLOCKED rather than PASS/FAIL. |
| Dev location override | `kDevLocation = LatLng(41.48, -81.78)` (Lakewood, OH) in **debug builds** | In `flutter run`/debug, GPS is bypassed and this fixed location is used. "Nearby"/distance results are relative to Lakewood, not the machine. Real GPS only runs in release builds. |
| Data source | Remote `export.json` (189 parishes, Cleveland/Akron) fetched at runtime, cached in SharedPreferences | First launch **requires internet**. No bundled asset. |
| Local data copy | `export.demo.json` | Use this to know what data *should* render; do not assume fields exist without checking. |
| Feedback backend | Cloudflare Worker `https://introibo-feedback.mfgarvin.workers.dev` | Submitting real feedback in QA writes to the live D1 store — use obvious test strings if you submit. |

**Rule of thumb:** a claim like "shows nearest parish" is only PASS if you either
(a) observed it in a running app, or (b) traced the exact code path that produces
it. State which.

---

## 1. App shell & navigation

- [ ] App launches to a **bottom `NavigationBar`** with exactly 3 tabs: **Home**, **Map**, **My Parishes**. `main.dart` `RootShell`.
- [ ] Tabs are backed by an `IndexedStack` — switching tabs **preserves scroll position and state** of the other tabs (they are not rebuilt from scratch).
- [ ] Selected tab shows the filled icon (`home`, `map`, `star`); unselected shows the outline variant.
- [ ] Nav bar and status/navigation bar colors adapt to light/dark theme (cream vs. true-black).
- [ ] There is **no** visible Android debug banner (`debugShowCheckedModeBanner: false`).

## 2. Home tab (`HomePage`)

### 2.1 First-run / connectivity
- [ ] On first launch **with no cached data and no internet**, an **"Internet Connection Required"** screen appears with a wifi-off icon and a **"Try Again"** button. `_buildRequiresInternetScreen`.
- [ ] "Try Again" shows a "Connecting…" spinner and re-attempts the fetch.
- [ ] When data loads from **cache because the network failed**, an orange **"Offline mode - data may be out of date"** snackbar appears (floating, ~4s). `_showOfflineWarning`.
- [ ] When fresh data loads successfully, **no** offline snackbar appears.

### 2.2 Header
- [ ] Title reads **"ParishFinder"** in the display font, in the theme's primary accent (oxblood light / candlelight dark).
- [ ] Subtitle "Find Catholic masses near you".
- [ ] A **menu (⋮/hamburger) button** opens a popup with **Settings**, **Feedback**, **About** — each opens as a bottom-up slide dialog.

### 2.3 Today hero card (`TodayHeroCard`)
- [ ] Shows a **day-aware suggestion** (Mass / Confession / Adoration) as the single dominant surface.
- [ ] Tapping it opens `FilteredParishListPage` with the matching filter, a matching title ("Mass Times"/"Confession"/"Adoration"), and the correct accent color.

### 2.4 "Looking for" quick filters
- [ ] Four buttons in a row: **Mass Times**, **Confession**, **Adoration**, **Parish Events**.
- [ ] Mass/Confession/Adoration open `FilteredParishListPage` with the right filter + accent (Mass=primary, Confession=`#5E3370` purple, Adoration=gold).
- [ ] **Parish Events** shows a **"Coming soon"** bottom sheet (it is intentionally not implemented) — must NOT navigate to a list.

### 2.5 Search
- [ ] Search field placeholder: "Search by name, city, or ZIP code".
- [ ] Typing filters parishes by **name, city, or ZIP**; matching is **accent/case-insensitive** via `normalizeForSearch` (e.g. searching "sebastian" matches "St. Sebastian"; diacritics normalized).
- [ ] Results are **debounced ~200ms** and capped at **5** autocomplete rows.
- [ ] Empty query → no results dropdown. Non-empty query with no matches → **"No parishes found"** row with a search-off icon.
- [ ] A row shows parish name + "City ZIP" + chevron; tapping opens `ParishDetailPage` and clears the search box.
- [ ] A clear (✕) button appears only when the field is non-empty and empties the field.
- [ ] Tapping outside the field dismisses the keyboard/results (when the field is empty).

### 2.6 Next-Mass tile (`NextMassTile`) — nearby only
- [ ] Renders a single live **"Next Mass Nearby"** tile, shown only when there are nearby parishes. (Home parishes are handled by their own section — see §2.9.)
- [ ] When the next Mass is **≤ 60 min** away ("imminent"), the tile renders as a **prominent square** (left half); otherwise a **compact full-width banner**.
- [ ] The tile announces when there are **no more Masses today**.
- [ ] Tapping the tile opens the detail page for the relevant parish.
- [ ] Time shown is correct relative to *now* — the soonest upcoming Mass, not a past one (see §7 occurrence math).

### 2.9 Your Home Parishes quick-launcher (`_HomeParishCard`)
- [ ] A **"Your Home Parishes"** section appears (between "Looking for" and "Search") **only when the user has ≥1 favorite**; entirely absent otherwise (no empty header).
- [ ] Shows **every** favorite parish as a card in a **horizontal** scroll — not collapsed to one. Each card: stained-glass avatar, amber star, name (≤2 lines), city, and **"Next · <day · time>"** for the next upcoming Mass ("Schedule unavailable" if none).
- [ ] Tapping a card opens that parish's detail page.
- [ ] Favoriting/unfavoriting a parish updates this row live (add/remove without a manual refresh).
- [ ] **Hero-tag safety:** a parish that is both a favorite *and* in the Nearby list must render on Home **without** a "multiple heroes share the same tag" crash (the home-parish card intentionally has no Hero).

### 2.7 Nearby parishes list
- [ ] While location or data is loading → a card with a spinner + "Finding nearby parishes…".
- [ ] If location is unavailable → "Location unavailable" card + "Try Again".
- [ ] Otherwise a **horizontal** scroll of up to **10** nearest parishes, each a 200px card with a stained-glass avatar, a **"X.X mi"** distance chip, name, city, and first Mass time.
- [ ] Distance chip value is plausible for Lakewood-relative (debug) coordinates (single-digit to low-double-digit miles for Cleveland-area parishes).

### 2.8 Liturgical day tile (`LiturgicalDayTile`)
- [ ] Always shows *something* (offline Computus baseline: season, liturgical color, generic title) even with no network. `LiturgicalService.localToday`.
- [ ] Best-effort enrichment from calapi may add a precise celebration/memorial name; absence of network must **not** blank the tile or crash.
- [ ] Liturgical color swatch matches the season (e.g. green Ordinary Time, purple Advent/Lent, white Easter/Christmas).

## 3. Map tab (`FindParishNearMePage`)

- [ ] Renders an **OpenStreetMap** `FlutterMap` (tiles from `tile.openstreetmap.org`).
- [ ] Shows **parish markers** for parishes with coordinates, plus a distinct **user-location marker**.
- [ ] A **swipeable carousel** (`PageView`) at the bottom pages through parishes; changing the page moves/relates to the map.
- [ ] Tapping a marker or carousel card opens `ParishDetailPage`.
- [ ] If location services/permission are denied → an explanatory state ("Please enable location services and grant permission…"), not a crash or blank map.
- [ ] Returning to the app foreground refreshes location **without** yanking the camera away from a manual pan/zoom.
- [ ] (Debug) uses `kDevLocation` (Lakewood) instead of real GPS.

## 4. My Parishes / Favorites tab (`FavoritesPage`)

- [ ] Lists parishes the user has favorited; empty state when none.
- [ ] Favoriting is **persistent** across app restarts (SharedPreferences key `favorite_parishes`).
- [ ] User-facing wording is **"home parishes"** even though the code/key says "favorites" — copy should say home parishes, not "favorites".
- [ ] Toggling a favorite on the detail page is reflected here immediately.
- [ ] Tapping an item opens its detail page.

## 5. Parish detail page (`ParishDetailPage`)

- [ ] Hero header: a **stained-glass** image keyed to the parish (`parishHeroTag`) animates in from the originating card. *(Smoothness is Android-only per project note — mark Linux BLOCKED.)*
- [ ] Address card is tappable → opens **Google Maps** directions for the address (`_launchMaps`).
- [ ] Phone → `tel:` launcher, only tappable when a real phone exists (not "No Phone Listed").
- [ ] Website → external browser, only when a real website exists (not "No Website").
- [ ] **Bulletin** card appears **only** when `bulletinUrl` is present/non-empty; opens it externally.
- [ ] Mass / Confession / Adoration schedule cards render from structured data (see §7). Adoration shows a **"Perpetual (24/7)"** treatment when `adorationIsPerpetual`.
- [ ] When navigated with a `focus` filter (from a filtered list), the matching schedule card is **scrolled into view and briefly highlighted**.
- [ ] Report / feedback affordance submits via the Worker (uses `SnackBar` for success/error).
- [ ] Missing optional fields (no image, no events, no bulletin) degrade gracefully — no "null"/"Unknown" leaking into the UI beyond the intended fallbacks (`address` → "No address provided", etc.).

## 6. Filtered parish list (`FilteredParishListPage`)

- [ ] Header count chip "**N parishes**" matches the number of cards actually shown.
- [ ] **Sort** segmented control (only when location known): **Soonest** (`nearestAndSoonest`), **Nearest** (`distance`), **A–Z** (`alphabetical`). Default is **Soonest**.
- [ ] **Soonest** default view hides parishes whose next occurrence is **> 2 days** (2880 min) out, with a **"Show N more parishes"** button revealing the rest. Switching sort or opening filters disables the 2-day cap.
- [ ] "Nearest" sorts strictly by distance; "A–Z" sorts by name; both stable.
- [ ] "Soonest" composite scoring: parishes **within 10 mi** are ordered by time-until-next; parishes **beyond 10 mi** are pushed below all near ones (score `10000 + distance`).
- [ ] **Filter sheet**: When (Any/Today/Tomorrow/This week), Time of day (Any/Morning/Afternoon/Evening), Day of week (Sun–Sat multi-select), and — **Mass filter only** — Language (Any/Spanish/Other). "Clear" appears only when a filter is active and resets all.
- [ ] Language filter is **absent** for Confession and Adoration lists (those carry no language).
- [ ] Applying filters correctly narrows the list; a filter matching nothing shows the empty state ("No parishes found").
- [ ] Each card shows up to **3** times as chips, "+N more" if more, and (Mass only) a **language badge** (ES/PL/LA/…) on non-English times.
- [ ] Distance chip shows in "Nearest" mode; a human time-until ("Starting soon", "Within the hour", "This evening", "Tomorrow morning", "In 2 days"…) shows in "Soonest" mode.

## 7. Schedule / occurrence math (`schedule_parser.dart`) — high-risk, test carefully

- [ ] Times parse from 24-hour `"HH:MM"` and display as 12-hour ("09:00" → "9:00 AM", "16:30" → "4:30 PM").
- [ ] Ranges collapse a shared meridiem ("3:00 – 3:30 PM", not "3:00 PM – 3:30 PM"); cross-meridiem keeps both.
- [ ] **Weekly** entries roll forward: an entry earlier *today* returns **next week's** occurrence, not today's past time. (`nextOccurrence`: `daysUntil == 0` + time already passed → +7 days.)
- [ ] **Dated** one-off entries (holidays/`mass_date`) occur on the fixed date and are **excluded once past** (`isPast`, `_upcomingOnly`).
- [ ] `findNextOccurrence` returns the genuinely soonest upcoming entry across a list.
- [ ] `groupByBucket` places entries into **today / tomorrow / thisWeek (≤7d) / beyond (8+d)** correctly.
- [ ] Language badge mapping: Spanish→ES, Polish→PL, Latin→LA, etc.; unspecified/"English" → **no badge**; compound "Bilingual (English-Polish)" resolves to the non-English badge; unknown → 2-letter uppercase fallback / "BIL".
- [ ] Unparseable entries (bad day, bad time, out-of-range H/M) are **skipped**, not crashed on (`fromJson` returns null).
- **Regression tests exist:** `test/schedule_parser_test.dart`, `test/search_normalize_test.dart` — run `flutter test` and confirm green.

## 8. Data model & loading (`parish.dart`, `parish_service.dart`)

- [ ] `Parish.fromJson` reads the **structured** shape (`schedules.mass/confession/adoration`, plain `latitude`/`longitude`, `bulletin_url`, `timestamp`). Legacy keys are gone.
- [ ] Missing required-ish fields fall back safely ("Unknown", "No address provided", "No Phone Listed", "No Website").
- [ ] `zip_code` handled whether it arrives as int or string.
- [ ] Loading is **cache-then-network**: cached JSON renders instantly; a successful fetch replaces it and re-caches; a failed fetch with cache present → offline mode; failed fetch with no cache → requires-internet.
- [ ] Network fetch has a **10s timeout** and non-200 is treated as failure.

## 9. Theming & accessibility

- [ ] Light = warm parchment/oxblood/gold; Dark = true-black/candlelight-gold. Toggling theme (Settings) updates **every** screen live.
- [ ] Gold is **not** used as low-contrast body text on cream — text-gold routes through `goldTextAccentFor` (deep bronze). Spot-check that accent *text* is legible (≥ ~4.5:1) on its background in both themes.
- [ ] Dark mode uses candlelight gold as the dominant accent (red does not glow on black).
- [ ] No text is clipped/overflowing on a narrow phone width; long parish names ellipsize (max 2 lines on cards).

## 10. Cross-cutting / regression

- [ ] `flutter analyze` is clean (no new warnings/errors).
- [ ] `flutter test` passes.
- [ ] No unguarded `!`/null-deref on optional fields (imageUrl, bulletinUrl, latitude/longitude, phone, website).
- [ ] Parishes **without coordinates** are simply omitted from nearby/map/distance — they must not crash or show "NaN mi".
- [ ] Rapid tab switching / back navigation does not leave dangling listeners (each `State` removes its `themeNotifier`/`favoritesManager` listeners in `dispose`).

---

## How to run QA (this machine)

Use the **`dart` MCP server** (preferred over raw shell for Flutter):

1. `mcp__dart__list_devices` → only `linux` is available here.
2. `mcp__dart__launch_app` (device `linux`) to start the app; `mcp__dart__list_running_apps` to get its DTD.
3. `mcp__dart__get_runtime_errors` after each interaction — treat any runtime error as FAIL.
4. `mcp__dart__get_widget_tree` / `get_selected_widget` to assert what's actually on screen.
5. `mcp__dart__hot_reload` after code tweaks; `mcp__dart__run_tests` for the unit suites.

**Cannot be verified on this box (mark BLOCKED):** real GPS behavior, Hero animation
smoothness, touch gestures, Android/iOS-specific rendering, and any screenshot-based
visual check (no screenshot tooling on the dev box). These need an Android emulator or
device.
</content>
</invoke>
