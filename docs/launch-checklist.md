# Going public: the 1.0.0 launch checklist

Written **2026-09-04**, when the app was in beta on both stores and the decision
was made to go public. **Updated 2026-09-19**: iOS is **live on the App Store**;
Android is still parked behind managed publishing. The 2026-09-13 update below
— both stores submitted, and the screenshot problem that gated iOS solved on
the Simulator (Step 1) — is kept as the record of the crossing. This is the one ordered runbook for that crossing; the
per-store mechanics live in [`play-release.md`](play-release.md) and
[`ios-testflight.md`](ios-testflight.md), and the Play copy in
[`play-listing.md`](play-listing.md). Nothing here repeats those — it says what
order to do them in, and what is still missing.

---

## Status: iOS is live (2026-09-19)

**ParishFinder 1.0.0 is public on the App Store**, released 2026-09-18 — the
first version of this app a stranger can install.

| | |
|---|---|
| Apple ID | **6803622742** (App Store Connect → App Information → General) |
| Listing | `https://apps.apple.com/us/app/parishfinder/id6803622742` |
| Build | `1.0.0`, CFBundleVersion 155 — the build submitted 2026-09-13, unchanged |
| Released | 2026-09-18; current version date 2026-09-19 |

That Apple ID is the number Step 5 was waiting on, and the only piece of the
launch that could not be written down in advance: it does not exist until the
App Store Connect record does, and nothing in the repo can derive it. It is now
in `site/index.html`, and this table is its second home.

**Google Play is still not public.** `play.google.com/store/apps/details?id=app.parishfinder`
returned 404 on 2026-09-19, which is what an unpublished listing returns —
managed publishing is doing exactly what it was turned on to do, parking the
approved release until someone presses Publish. Until then the hero carries one
badge and a "Coming soon to Google Play" note; see Step 5.

### What is still open

- **Press Publish on Google Play**, then finish Step 5's second badge.
- **Point the App Store listing's support URL at `/support`.** It was submitted
  with the bare homepage. App Store Connect takes the change without a new
  build, but it is a *listing* edit, so it goes out with the next version's
  review unless made now.
- **Watch the feedback Worker.** Public launch is the first time strangers
  submit corrections; the digest lands in Discord daily.

---

## Status: both stores are submitted (2026-09-13)

**iOS 1.0.0 (build 155) was uploaded with Transporter and submitted for App
Store review the same day Android went to production review.** Both listings are
now waiting on a reviewer; neither publishes without a human pressing a button.

| | |
|---|---|
| Version | `1.0.0`, **CFBundleVersion 155**, bundle `app.parishfinder` |
| Signed | `Apple Distribution: MICHAEL FRANCIS GARVIN (YYF433Z327)` |
| Device family | `UIDeviceFamily [1, 2]` — iPhone **and** iPad, so both screenshot sets were required |
| Built with | `tool/ios_build.sh` (never a bare `flutter build ipa`) |
| Screenshots | Simulator, not a borrowed phone — see Step 1 |

**No app code changed today.** The IPA is `bb76df0` (the `v1.0.0` tag) compiled
for iOS; the only commits are documentation. The screenshot work needed no
source edit at all, which was the point of finding the VM service route.

**iOS build 155 against Android's versionCode 154 is correct.** Both derive from
`max(git commit count, pubspec floor)`; the count advanced by one between the
two uploads. The numbers are per-platform and only have to increase within their
own store. Do not try to make them match.

### Verified before upload

`tool/ios_build.sh` refuses a debug IPA by checking for `kernel_blob.bin`, which
is the guard that matters — a debug build still carries `kDevLocation`'s
Lakewood mock, and shipping one pins every tester to Lakewood. It passed. Also
confirmed by hand: version `1.0.0` (purely numeric, as
`CFBundleShortVersionString` requires), the distribution certificate above, and
that Xcode had not rewritten `project.pbxproj` during the build.

### What is still open

*(As of 2026-09-19 the first of these is done — see the section above.)*

- ~~**App Store review.**~~ **Passed**; released 2026-09-18. The reviewer notes
  drafted in Step 4 preempted Guideline 5.2, and external TestFlight had
  already passed Beta App Review, so a reviewer had seen this app once without
  objecting.
- **Google Play production review**, with managed publishing **on** — approval
  parks the release until someone presses Publish. Still parked.
- ~~**Step 5 is untouched.**~~ Half done: the App Store badge is live in the
  hero with the real Apple ID; the Play badge waits on the paragraph above.

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

### iOS — shot on the Simulator, 2026-09-13

`TARGETED_DEVICE_FAMILY = "1,2"`, so the App Store requires **both** an iPhone
set and an iPad set. Both were taken on the Simulator and accepted:

| Simulator | Native capture | Apple slot |
|---|---|---|
| iPhone 17 Pro Max | 1320×2868 | 6.9″ |
| iPad Pro 13-inch (M5) | 2064×2752 | 13″ |

**This section used to say the Simulator was unusable because debug builds carry
the DEBUG ribbon. That was wrong**, and it cost a plan to borrow a phone. The
Simulator *is* debug-only — `IOSSimulator.supportsRuntimeMode` still accepts
`BuildMode.debug` alone in 3.47 — but the ribbon is not part of that bargain.
`flutter run` suppresses it around its own capture (press **`s`**;
`resident_runner.dart` wraps `takeScreenshot` in `_toggleDebugBanner`), and the
underlying switch is a VM service extension you can call yourself. Turn it off
once and it stays off for the life of the isolate, so the Simulator's own ⌘S
comes out clean too:

```bash
VM=$(grep -o 'http://127.0.0.1:[0-9]*/[A-Za-z0-9_=+-]*/' run.log | head -1)
ISO=$(curl -s "${VM}getVM" | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['isolates'][0]['id'])")
curl -s --get "${VM}ext.flutter.debugAllowBanner" \
  --data-urlencode "isolateId=$ISO" --data-urlencode "enabled=false"
```

The framework documents the hook at `widgets/app.dart` — "this is how
`flutter run` turns off the banner when you take a screen shot with 's'". So
options 2 and 3 above (a new `--dart-define`, or editing
`debugShowCheckedModeBanner`) are both unnecessary; neither was used, and the
invariant in CLAUDE.md — a location-mocked build is identifiable on screen —
survives untouched.

The rest of the recipe, in order:

```bash
xcrun simctl boot <udid>; open -a Simulator
xcrun simctl location <udid> set 41.4993,-81.6944       # Public Square
flutter run -d <udid> --dart-define=REAL_GPS=1
xcrun simctl privacy <udid> grant location app.parishfinder
xcrun simctl status_bar <udid> override --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --batteryState charged --batteryLevel 100
```

`REAL_GPS=1` is load-bearing: without it `kDevLocation` short-circuits
Geolocator and the simulated location is ignored, so you get Lakewood no matter
what `simctl` was told. Granting the permission up front keeps the system
prompt out of the frame.

**Three traps, each of which produced a bad frame before it was caught:**

- **After changing the simulated location, hot *restart* (`R`), not reload.**
  Hot reload preserves state, so the app never re-requests a fix and keeps
  showing the old one. Restart re-runs `main()`, which resets
  `debugAllowBannerOverride` — so re-disable the banner immediately after.
- **Check the parish names, not just that parishes appeared.** The iPad's first
  run came up with "Your diocese is not yet supported" over parishes in Stow,
  Cuyahoga Falls and Tallmadge — a Kent-area fix, and Kent is Portage County,
  which is Youngstown. The banner is the app correctly reporting that the
  location was wrong.
- **The status bar and the app's own clock must agree.** Apple's 9:41 convention
  against a hero reading "in 1h 54m" puts the real time at 3:36, and the
  mismatch is visible to anyone who looks. Either set `--time` to the real
  clock or move the real clock.

**Moving the real clock is what makes the hero good.** The Simulator takes its
time from the host, so the app's next-Mass logic follows the Mac. Sunday 9:41am
puts a 10:00 Mass fourteen minutes out — the best version of that banner. Note
the BSD argument order, which is `mmddHHMM` then `ccyy`, not the GNU order:

```bash
sudo systemsetup -setusingnetworktime off   # or NTP snaps it back
sudo date 091309412026                      # Sun 13 Sep 2026, 09:41
# ... shoot ...
sudo systemsetup -setusingnetworktime on    # restore
```

Don't commit while the clock is shifted. Verify `date` before you do.

**For a real device, none of this applies.** `xcrun devicectl` has no location
or time subcommand — location simulation on hardware is an Xcode debug-session
feature only, which puts you back in a debug build. The route that does work on
a release/TestFlight build is the app's own ZIP fallback: deny the location
permission and Home offers **"Use a ZIP code"**, resolved offline from the
parish data. It leaves visible traces — a "Near ZIP 44114" line under *Nearby
Parishes*, a pin-drop recentre icon, and distances measured to the ZIP centroid
— but it needs no code change and no Developer Mode on someone else's phone.

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
| Support URL | — | `https://parishfinder.app/support` — a real help page as of 2026-09-14. It was the bare homepage at submission; change it in App Store Connect, which needs no new build |
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

- ~~**Replace the placeholder on the marketing site.**~~ **Done 2026-09-19, by
  half.** The stores did not go live together, so the hero does not either: the
  App Store badge is live with Apple ID `6803622742`, and a quiet
  `<p class="play-soon">` note — "Coming soon to Google Play" — stands where
  the second badge will go. The Play anchor is still in the file, re-fenced
  inside a comment marked `PLAY-OFF` / `PLAY-ON`. **When Play is published, it
  is two edits**: delete those two fence lines and delete the `play-soon`
  paragraph. The Play URL needs no id — it is keyed on `app.parishfinder`.
  The site is Git-deployed via Cloudflare Pages, so pushing to `main` publishes
  it; never `wrangler pages deploy`.
- **Point both stores' support URL at `/support`.** The help page went up
  2026-09-14; the iOS listing was submitted with the bare homepage — and is now
  *live* with it, so this is a real user-facing gap, not a pre-launch nit —
  and Play's support field wants checking too. Neither needs a new build.
- ~~Add the screenshots to the landing page.~~ **Done 2026-09-14.** The
  "What it looks like" section is live with `shot-home.png` and
  `shot-parish.png` — Android profile-build captures, taken on an emulator with
  the clock at Sunday 10:30 and the location in downtown Cleveland, framed by
  `tool/framed_screenshot.py` and resized by `tool/site_screenshots.py`.
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
