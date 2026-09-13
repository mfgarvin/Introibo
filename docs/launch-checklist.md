# Going public: the 1.0.0 launch checklist

Written **2026-09-04**, when the app was in beta on both stores and the decision
was made to go public. **Updated 2026-09-13**: production access is granted, and
the Android screenshot set turned out to already exist (Step 1). This is the one ordered runbook for that crossing; the
per-store mechanics live in [`play-release.md`](play-release.md) and
[`ios-testflight.md`](ios-testflight.md), and the Play copy in
[`play-listing.md`](play-listing.md). Nothing here repeats those — it says what
order to do them in, and what is still missing.

---

## Status: Android is submitted (2026-09-13)

**Google Play 1.0.0 is uploaded to the production track and in review.** This
section is the handover; the dated table below is kept as the record of what
the crossing started from.

| | |
|---|---|
| Version | `1.0.0`, **versionCode 154**, versionName `1.0.0` |
| Tag | `v1.0.0`, annotated, at `bb76df0` — **pushed** |
| Signing | Verified pre-upload: `CN=Michael Garvin, O=St. Isidore Solutions`, block `META-INF/MYKEY.RSA` |
| Managed publishing | **On** — approval does *not* go live; someone presses Publish |
| Countries | United States only |
| Screenshots | Shot from the Android emulators at 1.0.0 |

**versionCode 154 against a pubspec that reads `+152` is correct, not drift.**
The build number is `max(git commit count, pubspec floor)`; two fixes landed
after `release.sh` set the floor. `tool/release.sh` resyncs the floor at the
next cut. Never hand-edit the version line to force them to match.

`android/key.properties` was recreated from the password manager for the build
and **deleted immediately after**, re-arming the guard in
`android/app/build.gradle` that makes an unsigned release build fail loudly.

### Four changes shipped after beta.9

- **Parish data re-fetches on resume** — `ParishService.refreshInterval` (24h),
  `staleThreshold` (7d) raising a Home banner. Before this, `_isLoaded` stayed
  true for the life of a process the OS keeps alive for weeks, so a phone could
  serve schedules fetched on install, indefinitely. **This matters more on iOS**,
  which suspends processes harder and longer than Android — worth confirming a
  resume actually delivers `AppLifecycleState.resumed` there.
- **The next-Mass tile has one shape.** It used to swell into a half-page square
  within 60 minutes of a Mass — 380dp on an 800dp tablet.
- **Feedback failures are sentences**, not a raw `SocketException`.
- Store copy synced to the live listing.

### For whoever picks up iOS (likely on another machine)

1. **`git pull --rebase` first.** The Mac checkout is behind; `v1.0.0` is at
   `bb76df0`.
2. **Do not run `tool/release.sh` on the Mac, and do not bump the version.**
   1.0.0 is already cut; iOS ships the same number. Build with
   **`tool/ios_build.sh`**, never a bare `flutter build ipa`.
3. **There is no CocoaPods.** Flutter 3.47 registers plugins via Swift Package
   Manager; `ios/Podfile` does not exist and must not be created. See
   [`ios-testflight.md`](ios-testflight.md), "No Podfile, by design".
4. **The Android screenshot trick does not transfer.** Android's store shots
   came from a *profile* build — no DEBUG ribbon, no `kDevLocation` mock, and no
   keystore needed (the signing guard only fires on task names containing
   "release"). The iOS Simulator runs **debug builds only**, so there is no
   equivalent; see Step 1 for the real options.

---

## Where things stood on 2026-09-04

| | Google Play | Apple App Store |
|---|---|---|
| Account | Enrolled; upload key enrolled, Play App Signing on | Enrolled 2026-08-20, individual |
| App identity | `app.parishfinder` — **permanent** | `app.parishfinder`, team `YYF433Z327` |
| Latest build | `1.0.0-beta.9`, versionCode **140**, uploaded 2026-09-02 | On TestFlight, **external** testing live |
| Testing gate | Closed test satisfied — **production access granted** 2026-09-13 | Beta App Review **passed** (external testing requires it) |
| Listing copy | Settled, [`play-listing.md`](play-listing.md) | **Not written** |
| Store graphics | Icon + feature graphic generated | Icon set generated |
| Screenshots | **In hand** — release-build set, see Step 1 | **None** |
| Privacy policy | Live — `https://parishfinder.app/privacy` | Same URL |

Both stores have already accepted a build of this app from these accounts. That
is the expensive part, and it is done. What remains is the iPhone screenshot
set, one version cut, and two listings.

**External TestFlight passing Beta App Review matters more than it looks.**
Apple has already looked at this app once and not objected to a directory of
Catholic parish schedules built from public bulletins. Beta App Review is
lighter than App Store review and grants nothing, but the most likely rejection
reason — Guideline 5.2, using another organization's name and material — has
had one pass in front of a reviewer already.

---

## The shape of it

One version cut serves both stores. Android's screenshots already exist; the
iPhone set is the one asset still missing, so it no longer gates Android. So:

```
screenshots ──┬─→ Play listing ─→ promote to production
              └─→ App Store listing ─→ submit for review
       1.0.0 cut ─┴─→ AAB (Linux) + IPA (Mac)
```

Android can go the whole way now. iOS waits on its screenshots.

---

## Step 1 — Screenshots

Still the blocking asset for iOS. **Android is done** — the set already existed
and was found on 2026-09-13. Also **check the Play Console before reshooting
anything**: Play generally requires a complete store listing before a closed
track can publish, so phone screenshots may already be sitting there from when
the closed test was set up.

### Android — already in hand

A clean release-build set is at **`~/Desktop/emulator/`**, captured 2026-08-06.
No DEBUG ribbon, real data, clean status bar, and it happens to match the order
in [`play-listing.md`](play-listing.md) § Screenshot plan:

| File (`Screenshot_…`) | Screen |
|---|---|
| `1786022701` | Home + next-Mass banner |
| `1786022718` | Map, markers, carousel |
| `1786022709` | Parish detail, full Mass schedule |
| `1786022713` | Mass Times — Soonest |
| `1786022714` | Mass Times — Nearest |

All 1080×2400. Tablet sets are there too — 1600×2560 (10") and 1200×1920 (7") —
optional for Play, but it surfaces large-screen-ready apps separately.

**Do not use `screenshots/` in this repo.** It is gitignored driver output, and
everything in it as of 2026-09-13 is debug-build: DEBUG ribbon, and in
`device_01_home.png` the first-run disclaimer dialog covering the page.
`Screenshot_1788135205.png` on the Desktop (2026-08-30) is debug too.

The one staleness caveat: the Aug 6 set predates beta.9, so the parish-detail
shot shows the older, smaller day chips without the First Friday label. Play
does not require screenshots to match the build, so this is optional — but if
you want it current, reshoot that single frame from the release build you are
already making in Step 2.

If reshooting, three things ruin a capture and are only obvious afterwards:

- **The Home hero is time-sensitive.** Shoot when a Mass is actually upcoming.
  Late evening and the banner generalizes to "Tomorrow morning" or shows the
  "No more today" chip — truthful, but not the screenshot you want first in
  search results.
- **Pick a parish with a full record** for the detail shot — St. Sebastian
  (Akron, `0689`) carries Mass, confession and adoration.
- Silence notifications first; a banner across the status bar is a re-shoot.

Play wants 2–8 phone images, 16:9 or 9:16, 320–3840 px. Both the Pixel's native
resolution and the 1080×2400 set above qualify as-is.

### iOS — take them from TestFlight, not the Simulator

`TARGETED_DEVICE_FAMILY = "1,2"`, so the App Store requires **both** an iPhone
set and an iPad set. Confirm the exact required display sizes in App Store
Connect when you upload — Apple has consolidated them more than once, and the
current requirement is roughly one 6.9″ iPhone set and one 13″ iPad set.

**The iPad set comes off the TestFlight build**, which is a release build: no
DEBUG banner, no mocked location. That is the whole solution for iPad, and it
is already installed.

**The iPhone set is the actual problem.** There is no iPhone here, and the
Simulator runs debug builds only — which carry the DEBUG ribbon *and*
`kDevLocation`'s Lakewood mock. Three ways out, in order of preference:

1. **Borrow a 6.9″ iPhone and install the TestFlight build.** External testing
   is already running, so a public link makes this a five-minute favour from
   anyone with a recent iPhone. No code changes, real build, correct pixels.
2. Gate the banner behind a new `--dart-define`. Works, but it adds a second
   behavioural difference between debug and release, and the DEBUG ribbon is
   deliberately left on precisely so a location-mocked build is identifiable on
   screen (see CLAUDE.md, "Dev Location Override"). Don't do this quietly.
3. Flip `debugShowCheckedModeBanner` locally and never commit it. Same objection
   as (2), plus a change that must not survive the session.

Do not resize the Android captures. The screenshots must show the iOS UI.

---

## Step 2 — Cut 1.0.0

**On Linux only.** Never run `tool/release.sh` on the Mac; the two checkouts
would race the tag.

```bash
git pull --rebase
tool/release.sh show           # confirm: 1.0.0-beta.9+140
tool/release.sh release        # -> 1.0.0, commits, tags v1.0.0
flutter analyze && flutter test
```

`release` refuses to run on a dirty tree and refuses a tag that already exists.
It rewrites the `+N` floor to the new commit count, which is what keeps the
build number monotonic on both platforms.

Then the release notes. `docs/store/whatsnew-1.0.0.txt` is **not** a beta
changelog — it is the first thing a stranger reads about the app, so it should
say what ParishFinder *is*, not what changed since beta.9. Adapt the opening of
the full description in [`play-listing.md`](play-listing.md).

### The Android artifact

```bash
# Recreate android/key.properties from the password manager (see play-release.md).
flutter build appbundle --release
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
rm android/key.properties      # put the guard back
```

The certificate must read `CN=Michael Garvin, O=St. Isidore Solutions` and the
signature block `META-INF/MYKEY.RSA`. Leaving `key.properties` on disk is how a
later release build quietly signs with whatever key was last configured.

### The iOS artifact

On the Mac, after `git pull --rebase`:

```bash
tool/ios_build.sh              # not a bare `flutter build ipa`
```

It strips the (now absent) prerelease suffix, derives the build number from the
commit count, and refuses to bless a debug IPA. Upload with Transporter.

---

## Step 3 — Google Play to production

Two separate things happen here, and neither publishes anything by itself:
**applying for production access** is an eligibility review of the account, and
**creating a production release** is the explicit act of shipping. Approval of
the first does not trigger the second.

### 3a. Applying for production access — **done**

Granted as of 2026-09-13, so this step is history. Recorded for the next app:
the application is a form, not a button — it asks how testers were recruited,
how feedback was gathered, what was learned, and what changed as a result. The
answers are free text and Google wants specifics. Draft them before opening the
form; the closed test and the feedback Worker's D1 are the evidence. Review took
up to about a week. Nothing goes live when it clears — it only unlocks the
production track.

### 3b. Creating the production release

Release → Production → Create new release. Play will offer to **promote** a
build from a testing track, and it will offer the app bundle library, which
holds every AAB already uploaded.

**Do not promote versionCode 140.** Its version name is `1.0.0-beta.9`, and
that string is what the public listing would show. Cut 1.0.0 first (Step 2); the
fresh build takes a higher versionCode from the commit count, so nothing
collides with 140.

Then:

1. Upload the 1.0.0 AAB to the **production** track.
2. **Check what the main store listing already holds.** The listing is shared
   across every track — it is not per-release — so whatever is in it goes public
   with production. Play generally requires a complete listing before a closed
   track can publish, which means screenshots may already be sitting in the
   console from when the closed test was set up. Look before reshooting. If what
   is there is placeholder-grade, replace it now: production is when strangers
   first see it. The copy is settled in [`play-listing.md`](play-listing.md).
3. Confirm the **App content** declarations are still green. Data Safety,
   content rating, target audience and the ads declaration were all required
   before the closed test could run, so they exist — this is a verify, not a
   redo. [`play-data-safety.md`](play-data-safety.md) holds the answers if
   anything needs re-stating.
4. Countries: **United States only.** The data covers eight Ohio counties;
   worldwide availability buys nothing but reviews from people who cannot use
   the app.
5. Release notes: `docs/store/whatsnew-1.0.0.txt`.
6. Roll out. A staged rollout is available, but with an audience this size a
   staged percentage mostly slows down the feedback you actually want. Full
   rollout is reasonable; the real safety net is Play Console vitals plus the
   feedback Worker's daily Discord digest.

### Turn on Managed publishing first

Publishing overview → **Managed publishing**, before submitting. Without it, an
approved release goes live the instant review finishes — which may be 3am. With
it, approval parks the release until you press Publish. That is what lets the
store listing, the site badges (Step 5) and any announcement land together.

Expect the first production review to take days rather than the minutes an
internal-track upload takes.

---

## Step 4 — App Store submission

The build is already on TestFlight, so this step is almost entirely metadata.
Fields Apple wants that Play has no equivalent for:

| Field | Limit | Where the copy comes from |
|---|---|---|
| Name | 30 | `ParishFinder` |
| Subtitle | 30 | **New copy.** The Play short description is 76 chars — too long. Something like "Mass times near you" |
| Keywords | 100 | **New copy, comma-separated, no spaces.** Apple's main search lever; there is no Play equivalent. Do not repeat words already in the name or subtitle — Apple indexes those separately. Candidates: `catholic,mass,confession,adoration,parish,church,cleveland,diocese,bulletin,liturgical` |
| Promotional text | 170 | Editable without a new build — useful later for holy-day notes |
| Description | 4000 | Adapt the full description from [`play-listing.md`](play-listing.md) |
| Support URL | — | `https://parishfinder.app` |
| Category | — | Primary **Lifestyle** (matches the settled Play category); Reference is the sensible secondary |

Then:

- **App Privacy questionnaire** — a different form from Play's Data Safety with
  the same answers: feedback is the only thing collected, location never leaves
  the device. See [`play-data-safety.md`](play-data-safety.md).
- **Age rating questionnaire** — expect the lowest tier.
- **Pricing and availability** — free, United States, to match Play.
- **Screenshots** — iPhone and iPad sets from Step 1.
- **Notes for the reviewer.** Worth writing, and worth writing plainly:

  > ParishFinder is a personal project of a Catholic priest. It lists publicly
  > available Mass, confession and adoration times compiled from parish
  > bulletins and parish websites in the Diocese of Cleveland. It is not an
  > official app of the diocese or of any parish, and the app states this in its
  > description and on its About page. No account or login is required.

  That preempts Guideline 5.2 by answering it before it is asked. Guideline 4.2
  (minimum functionality) is a low risk here — map, offline cache, saved
  parishes and the liturgical calendar are well past a static list.

- Select the build, submit for review.

---

## Step 5 — Once both are live

- **Replace the placeholder on the marketing site.** `site/index.html` line 45
  still carries "Coming soon to Google Play and the Apple App Store" — it is
  marked as a placeholder in `site/CONTENT.md` (§ the launch badge). Real store
  badges and links go there. The site is Git-deployed via Cloudflare Pages, so
  pushing to `main` publishes it; never `wrangler pages deploy`.
- Watch the feedback Worker's Discord digest and the `/admin` dashboard. Public
  launch is the first time strangers submit corrections, and the data quality
  argument for this app is entirely downstream of that.
- **TestFlight builds expire 90 days after upload.** An external beta group
  needs a fresh build roughly quarterly, independently of App Store releases.
- Play's target-API requirement moves annually — expect API 37 around August
  2027.
- Deferred deliberately: `flutter_map` is a major version behind (7.0.2 vs 8.x),
  and the Gradle/AGP/Kotlin toolchain warning from the beta.9 build. Neither
  blocks launch; both come due at the next Flutter upgrade.

---

## Later, if St. Isidore Solutions becomes a real organization

Shipping under an individual account now costs nothing later. **Both stores
support transferring an existing app to another developer account without
resubmission or re-review** — the app keeps its bundle ID, store URL, ratings,
reviews and ranking history, and existing users take updates normally.

Apple's conditions: at least one released version, nothing pending in review,
and no iCloud, Sign in with Apple, Apple Pay, Wallet passes, or shared App
Groups. ParishFinder uses none of those; location is a plist string, not an
entitlement.

Two things to get right:

- **Never pre-register `app.parishfinder` on the destination account.** The
  transfer moves the identifier. If the receiving account already owns the
  bundle ID, the transfer is blocked with no clean way out.
- **TestFlight testers and signing assets do not transfer.** Certificates and
  profiles are per-team; the new account regenerates them and builds the next
  update from there, and an external tester group has to be rebuilt.

The visible consequence of the switch is the seller name on the store listing —
today it is the legal individual name on the Apple account.

*(Store transfer mechanics change; confirm the current conditions in App Store
Connect and Play Console before committing to a date.)*
