# Play Console — Data Safety form answers

Google requires this declaration for every app, and it must match what the app
actually does. These answers were derived by auditing the source, not from
assumption. If any of the cited code changes, revisit this file.

**Rule of thumb Google applies:** "collection" means data leaving the device to
a server you control. Data that stays on the device is *not* collection, and
neither is data that goes only to a third party the user's device contacts
directly.

---

## Summary answers

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS to the feedback Worker) |
| Do you provide a way for users to request that their data is deleted? | **Yes** (email request, per the privacy policy) |

---

## Data types to declare

### Personal info → Email address

- **Collected:** Yes
- **Shared:** No
- **Processed ephemerally:** No — it is stored
- **Required or optional:** **Optional.** The user only supplies it if they want
  a reply to their feedback.
- **Purpose:** App functionality (replying to a data-correction report), Customer
  support

*Source: `reply_email` in `lib/services/feedback_client.dart`, stored by
`worker/src/index.ts`.*

### App activity → Other user-generated content

- **Collected:** Yes
- **Shared:** No
- **Required or optional:** Optional — only when the user submits the
  "Is this information accurate?" form
- **Purpose:** App functionality (correcting parish schedule data)

*Covers the free-text body, the selected issue categories, the accurate/issue
status, and the parish name and ID the report refers to.*

### App info and performance → Other app performance data

- **Collected:** Yes
- **Shared:** No
- **Required or optional:** Optional — sent only as part of a feedback submission
- **Purpose:** App functionality

*Covers `app_version`, `build_number`, and `platform`, which accompany each
feedback submission so reports can be tied to a build.*

### Device or other IDs → Device or other IDs

- **Collected:** Yes
- **Shared:** No
- **Required or optional:** Optional — only on feedback submission
- **Purpose:** **Fraud prevention, security, and compliance**

*The Worker records the caller's IP (`CF-Connecting-IP`) in the `client_ip`
column solely to rate-limit the feedback form. Google treats IP address as an
identifier for this form. Declare it — an undeclared identifier is a common
cause of policy enforcement.*

---

## Data types NOT to declare — and why

### Location — **do not declare as collected**

The app requests `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` and reads the
device position on the Map tab, but the coordinates are **used entirely on
device** — to centre the map and sort parishes by distance — and are never
transmitted anywhere. The feedback payload contains no location field.

Google's definition of collection is transmission off the device, so this is
correctly declared as *not collected*. Requesting a runtime permission does not
by itself constitute collection.

> Be ready to explain this if review asks. The honest one-liner: *"Location is
> read on-device to centre the map and sort by distance; it is never
> transmitted, stored, or shared."*

### Files and docs / caches — not collection

Home parishes, the cached parish directory, the cached liturgical calendar, the
first-run notice flag, and the theme preference are all local
`SharedPreferences` state that never leaves the device.

### Third-party network requests — not collection *by you*

The device contacts GitHub (parish JSON), OpenStreetMap (map tiles), and
`calapi.inadiutorium.cz` (liturgical calendar). Each necessarily sees the device
IP as part of serving the request, but none of it is collected by or shared with
you, so it is not declared here. It **is** disclosed in the privacy policy,
which is the right place for it.

Fonts are bundled in the app, so there is no request to `fonts.gstatic.com` and
no Google dependency to disclose.

---

## Also in the Play Console

- **Ads:** No, this app contains no ads.
- **Content rating:** expect "Everyone" — no violence, no user-to-user
  communication, no purchases.
- **Government app:** No.
- **Financial features:** None.
- **Data deletion:** provide `contact@parishfinder.app` as the deletion request
  channel. There are no accounts, so no account-deletion URL is required.

---

## Permission justifications

If prompted to justify the location permissions:

> ParishFinder uses location to show the user which Catholic parishes are near
> them on a map and to sort parish lists by distance. Location is processed
> entirely on the device and is never transmitted or stored. The permission is
> optional — all other functionality, including search and full parish details,
> works without it.
