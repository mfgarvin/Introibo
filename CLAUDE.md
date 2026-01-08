# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Introibo is a Flutter mobile application for finding Catholic parishes and mass times in the Cleveland/Akron, Ohio area. It provides two main features:
1. **Research a Parish** - Search parishes by name, city, or ZIP code
2. **Find a Parish Near Me** - Interactive map showing nearby parishes using GPS

## Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Run static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/widget_test.dart  # Run single test file

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
main.dart (MassGPTApp)
    └── HomePage
            ├── "Research a Parish" → ResearchParishPage → ParishDetailPage
            └── "Find a Parish near me" → FindParishNearMePage → ParishDetailPage
```

### Core Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, theme config, HomePage with two navigation buttons |
| `lib/globals.dart` | Global ParishService singleton (currently unused - data loaded locally) |
| `lib/models/parish.dart` | Parish data model with `fromJson` factory |
| `lib/services/parish_service.dart` | HTTP-based parish loader (unused - kept for future API integration) |

### Pages

| Page | Purpose |
|------|---------|
| `lib/pages/research_parish_page.dart` | Search UI with debounced text input, filters by name/city/zip |
| `lib/pages/find_parish_near_me_page.dart` | OpenStreetMap view with GPS location and parish markers |
| `lib/pages/parish_detail_page.dart` | Displays parish info: address, mass times, confession times, phone, website |

### Data Flow

Both `ResearchParishPage` and `FindParishNearMePage` load parish data independently from the local JSON asset:
```dart
rootBundle.loadString('data/parishes.json')  // or DefaultAssetBundle.of(context).loadString()
```

The `ParishService` in `lib/services/` exists for future HTTP-based loading but is currently commented out in `main.dart`.

### Data Model

`Parish` class fields:
- `name`, `address`, `city`, `zipCode`, `phone`, `website`
- `parishId` - optional unique identifier
- `massTimes: List<String>` - e.g., `["Sunday: 10:30AM", "Monday: 8:00AM"]`
- `confTimes: List<String>` - confession schedule
- `adoration: List<String>` - adoration schedule
- `eventsSummary` - optional paragraph describing upcoming parish events
- `latitude`, `longitude` - nullable, used for map markers (currently not in data)
- `contactInfo`, `imageUrl` - optional

JSON field mapping: `parish_id`, `zip_code`, `website`, `mass_times`, `confessions`, `adoration`, `events_summary`

### Key Dependencies

- `flutter_map` + `latlong2` - OpenStreetMap tile rendering and coordinates
- `geolocator` + `permission_handler` - GPS location with permission handling
- `flutter_dotenv` - Environment variables (imported but currently unused)

### Theme

Defined as global constants in `main.dart` (inspired by [travel_app](https://github.com/Shadow60539/travel_app)):
- `kBackgroundColor`: `#FEFEFE` (off-white)
- `kPrimaryColor`: `#3F95A1` (teal)
- `kSecondaryColor`: `#003366` (dark blue)
- `kCardColor`: `Colors.white`

Typography uses Google Fonts (Lato) via the `google_fonts` package.

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

`data/parishes.json` contains ~80+ parishes in Ohio. Sample entry:
```json
{
  "name": "St. Sebastian Parish",
  "parish_id": "0689",
  "address": "476 Mull Ave",
  "city": "Akron",
  "zip_code": "44320",
  "phone": "330-836-2233",
  "website": "www.stsebastian.org",
  "mass_times": [
    "Sunday: 9:00AM, 11:00AM",
    "Saturday: 8:00AM, 4:30PM - Vigil Mass"
  ],
  "confessions": [
    "Tuesday: 7:00PM to 7:30PM",
    "Saturday: 9:30AM to 10:00AM"
  ],
  "adoration": [
    "Tuesday: 8:30AM to 7:40PM"
  ],
  "events_summary": "St. Sebastian Parish has several Feast Day celebrations coming up..."
}
```

**Note:** The current data format does not include `latitude`/`longitude` coordinates. The map feature ("Find a Parish Near Me") and distance-based sorting require coordinates to function.

## Session Log: 2026-01-01

Changes made during initial setup session:

1. **Created CLAUDE.md** - This documentation file

2. **Added dev location override** (`lib/pages/find_parish_near_me_page.dart`)
   - Added `kDevLocation` constant using `kDebugMode` from `flutter/foundation.dart`
   - Modified `_getUserLocation()` to check for dev override before calling Geolocator
   - Enables map testing on Linux desktop without GPS hardware

3. **Fixed OSM tile warnings** (`lib/pages/find_parish_near_me_page.dart`)
   - Removed `{s}` subdomain placeholder from tile URL
   - Removed `subdomains: ['a', 'b', 'c']` parameter
   - Fixes flutter_map warnings about deprecated OSM subdomain usage

4. **Environment setup**
   - Installed Flutter via snap
   - Installed Android Studio and SDK via snap
   - Configured Flutter to use Android SDK at `~/Android/Sdk`
   - Accepted Android licenses

## Session Log: 2026-01-02

Changes made to fix Android build:

1. **Upgraded Android Gradle Plugin** (`android/settings.gradle`)
   - AGP 7.3.0 → 8.6.0
   - Required for compatibility with modern Flutter and Kotlin versions

2. **Upgraded Kotlin version** (`android/settings.gradle`)
   - Kotlin 2.0.21 → 2.1.0
   - Cleaned up commented-out version lines

3. **Updated Java compatibility** (`android/app/build.gradle`)
   - Java 8 → Java 17 (required by AGP 8.x)
   - Updated `sourceCompatibility`, `targetCompatibility`, and `jvmTarget`

4. **Fixed AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`)
   - Removed deprecated `package` attribute from `<manifest>` tag
   - Namespace is now defined only in `build.gradle` via `namespace` property

### UI Redesign (2026-01-02)

Complete UI redesign inspired by [Shadow60539/travel_app](https://github.com/Shadow60539/travel_app):

1. **Added `google_fonts` dependency** (`pubspec.yaml`)
   - Clean Lato typography throughout the app

2. **New color scheme** (`lib/main.dart`)
   - Changed from dark blue background to light off-white theme
   - Teal (`#3F95A1`) as primary accent color
   - Dark blue (`#003366`) as secondary color
   - White cards with subtle shadows

3. **Redesigned HomePage** (`lib/main.dart`)
   - Header with app title and church icon
   - "Discover" section label
   - Two large action cards with icons, subtitles, and arrow indicators
   - Info card showing coverage area (80+ parishes)

4. **Redesigned ResearchParishPage** (`lib/pages/research_parish_page.dart`)
   - Modern rounded search bar with shadow
   - Empty state with icon and instructions
   - Parish cards showing name, address, and first mass time
   - Result count display

5. **Redesigned FindParishNearMePage** (`lib/pages/find_parish_near_me_page.dart`)
   - Full-screen map with floating back button
   - Info card overlay: "Parishes Near You"
   - Custom user location marker (teal dot with glow)
   - Custom parish markers (blue circles with church icon)
   - Modern bottom sheet when tapping a parish

6. **Redesigned ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Collapsing SliverAppBar with gradient header
   - Card-based layout for all info sections
   - Consistent styling with rounded corners and shadows

### HomePage Search & Quick Access (2026-01-02)

Enhanced HomePage with inline search and quick access buttons:

1. **Replaced "Research a Parish" card with search bar** (`lib/main.dart`)
   - Inline search with autocomplete dropdown (up to 5 results)
   - Debounced search (200ms) for smooth typing
   - Results show parish name, city, and ZIP code
   - Tapping a result navigates directly to ParishDetailPage
   - "No parishes found" message when no matches

2. **Added "Looking for" quick access section**
   - 4 quick access buttons in a row:
     - Mass Times (teal)
     - Confession (dark blue)
     - Adoration (orange)
     - Parish Details (purple)
   - Each button has icon, label, and colored background
   - Placeholder onTap handlers for future functionality

3. **HomePage layout order**
   - Header (MassGPT title + church icon)
   - Subtitle
   - Search Parishes section with autocomplete
   - Looking for section (4 quick buttons)
   - Nearby Parishes section (horizontal scrolling list)
   - Info section (coverage area)

### Nearby Parishes List (2026-01-02)

Replaced "Find a Parish Near Me" card with a horizontal scrolling list of nearby parishes:

1. **Added location functionality to HomePage** (`lib/main.dart`)
   - Added `kDevLocation` constant (mirrors the one in `find_parish_near_me_page.dart`)
   - Added `_getUserLocation()` method with dev override support
   - Added `_calculateDistance()` using Haversine formula (returns miles)
   - Added `_updateNearbyParishes()` to sort and select 10 nearest parishes

2. **New "Nearby Parishes" section**
   - Section header with "View All" button (navigates to map view)
   - Horizontal scrolling `ListView` showing 10 nearest parishes
   - Loading state: spinner with "Finding nearby parishes..." message
   - Error state: "Location unavailable" with "Try Again" button
   - Empty state: "No parishes found nearby" message

3. **`_NearbyParishCard` widget**
   - Fixed width (200px) cards in horizontal scroll
   - Church icon and distance badge (e.g., "1.2 mi") in header
   - Parish name (up to 2 lines) and city
   - First mass time with clock icon at bottom
   - Tapping navigates to `ParishDetailPage`

4. **Removed unused `_ActionCard` class**
   - No longer needed since the action card was replaced with the list

### Quick Access Button Filters (2026-01-02)

Implemented functionality for the four quick access buttons on HomePage:

1. **New `FilteredParishListPage`** (`lib/pages/filtered_parish_list_page.dart`)
   - Reusable page for displaying filtered parish lists
   - `ParishFilter` enum: `massTimes`, `confession`, `all`
   - `SortOrder` enum: `distance`, `alphabetical`
   - Default sort by distance (nearest first)
   - Toggle button to switch between "Nearest" and "A-Z" sorting
   - Distance badges on cards when sorted by distance
   - Shows parish count, times (up to 3 with "+N more" indicator)

2. **Quick access button actions** (`lib/main.dart`)
   - **Mass Times**: Opens `FilteredParishListPage` with mass times filter
   - **Confession**: Opens `FilteredParishListPage` with confession filter
   - **Adoration**: Shows "Coming Soon" bottom sheet (no data yet)
   - **Parish Events**: Shows "Coming Soon" bottom sheet (for future expansion)

3. **Sort toggle feature**
   - Button in top-right shows current sort mode
   - Tapping toggles between distance and alphabetical
   - Distance calculated using Haversine formula
   - Falls back to alphabetical if location unavailable

4. **Reusable `_showComingSoon` method**
   - Generic bottom sheet for "Coming Soon" features
   - Accepts icon, title, message, and accent color
   - Used by Adoration and Parish Events buttons

### App Menu & Settings (2026-01-02)

Added dropdown menu to the church icon in the top-right of HomePage:

1. **PopupMenuButton on church icon** (`lib/main.dart`)
   - Favorites option (heart icon)
   - Settings option (gear icon)
   - Feedback option (feedback icon)

2. **FeedbackPage** (`lib/main.dart`)
   - Full-screen modal overlay with slide-up animation
   - Header showing feedback destination: `feedback@massgpt.org`
   - Optional email field for replies
   - Multi-line feedback text area
   - Submit button with loading state and success notification

3. **SettingsPage** (`lib/main.dart`)
   - Dark mode toggle switch
   - Version info display (1.0.0)
   - Full dark mode support

4. **ThemeNotifier** (`lib/main.dart`)
   - Global `ChangeNotifier` for app-wide theme management
   - `isDarkMode` getter and `toggleTheme()`/`setDarkMode()` methods
   - `MassGPTApp` converted to `StatefulWidget` to listen for theme changes
   - Both light and dark `ThemeData` configured in `MaterialApp`

5. **Dark mode color constants** (`lib/main.dart`)
   - `kBackgroundColorDark`: `#1A1A2E` (dark blue)
   - `kCardColorDark`: `#16213E` (slightly lighter dark blue)

### Favorites Feature (2026-01-02)

Implemented favorites system allowing users to save parishes:

1. **FavoritesManager** (`lib/main.dart`)
   - Global `ChangeNotifier` for managing favorites
   - `isFavorite()`, `toggleFavorite()`, `addFavorite()`, `removeFavorite()` methods
   - Stores favorites by parish name in a `Set<String>`

2. **Star icon on ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Added favorite toggle button in app bar (top-right)
   - Empty star (outline) when not favorited
   - Filled amber star when favorited
   - Listens to `FavoritesManager` for real-time updates

3. **FavoritesPage** (`lib/main.dart`)
   - Full-screen modal showing all favorited parishes
   - Empty state with instructions when no favorites
   - Parish cards with name, city, mass time, and remove button
   - Tapping a card navigates to ParishDetailPage

4. **Persistence with SharedPreferences** (`lib/main.dart`, `pubspec.yaml`)
   - Added `shared_preferences: ^2.2.2` dependency
   - `FavoritesManager.init()` loads favorites from storage on app start
   - Favorites saved automatically when modified
   - Favorites persist across app restarts

### Dark Mode Support (2026-01-02)

Added comprehensive dark mode support throughout the app:

1. **HomePage** (`lib/main.dart`)
   - Added `themeNotifier` listener to `_HomePageState`
   - Theme-aware color getters: `_isDark`, `_backgroundColor`, `_cardColor`, `_textColor`, `_subtextColor`
   - Updated all section headers, subtitles, and info cards

2. **Search bar and autocomplete** (`lib/main.dart`)
   - Input text, hints, and clear button use theme colors
   - Search results dropdown adapts to dark mode
   - Dividers and icons use appropriate colors

3. **Quick access buttons** (`lib/main.dart`)
   - `_QuickAccessButton` reads theme from `themeNotifier`
   - Card background and label text adapt to theme

4. **Nearby parishes list** (`lib/main.dart`)
   - `_NearbyParishCard` accepts theme colors as parameters
   - Loading, error, and empty states use theme colors

5. **Coming soon dialogs** (`lib/main.dart`)
   - Card background, title, and message use theme colors

6. **FeedbackPage** (`lib/main.dart`)
   - App bar, labels, inputs, and hints adapt to theme

7. **SettingsPage** (`lib/main.dart`)
   - Already had full dark mode support

8. **FavoritesPage** (`lib/main.dart`)
   - Already had full dark mode support

9. **ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Added `themeNotifier` listener
   - Background, cards, and all text adapt to theme
   - All helper widgets (`_InfoCard`, `_ScheduleCard`, `_ContactRow`) accept theme colors

### Tap-to-Action for Contact Info (2026-01-02)

Added interactive actions for address, phone, and website on ParishDetailPage:

1. **url_launcher dependency** (`pubspec.yaml`)
   - Enables launching external URLs for maps, calls, and websites

2. **Address Card** (`lib/pages/parish_detail_page.dart`)
   - New `_TappableInfoCard` widget with "Get Directions" action button
   - Tapping opens Google Maps with the encoded parish address

3. **Contact Row Actions**
   - New `_TappableContactRow` widget with visual feedback
   - **Phone**: Tapping initiates a phone call via `tel:` URL
   - **Website**: Tapping opens the website in external browser
   - Non-actionable items appear grayed out (no underline/arrow)

4. **Helper methods**
   - `_launchMaps()` - Opens Google Maps search with address
   - `_launchPhone()` - Strips non-digits and launches tel: URL
   - `_launchWebsite()` - Adds https:// if needed, opens in browser

### Parish Images (2026-01-02)

Added support for parish images in the detail page header:

1. **cached_network_image dependency** (`pubspec.yaml`)
   - Efficient image loading with caching and placeholders

2. **Parish model update** (`lib/models/parish.dart`)
   - Added optional `imageUrl` field
   - JSON key: `image_url`

3. **ParishDetailPage header** (`lib/pages/parish_detail_page.dart`)
   - `_buildHeaderBackground()` - Checks for image URL
   - If image exists: Shows cached image with gradient overlay for text readability
   - If no image: Shows placeholder with gradient background and church icon
   - `_buildPlaceholderBackground()` - Reusable placeholder widget

4. **Adding images to parishes**

   To add an image for a parish, add the `image_url` field to the parish entry in `data/parishes.json`:
   ```json
   {
     "name": "Transfiguration",
     "latitude": 41.4771636,
     "longitude": -81.7767796,
     "address": "12608 Madison Avenue",
     "city": "Lakewood, OH",
     "zip_code": "44107",
     "phone": "(216) 521-7288",
     "www": "lakewoodcatholicacademy.com",
     "image_url": "https://example.com/transfiguration-church.jpg",
     "mass_times": ["Sunday: 9:00AM", "Saturday: 4:00PM"],
     "conf_times": ["Saturday: 3:15PM to 3:45PM"]
   }
   ```

   **Image recommendations:**
   - Use HTTPS URLs for security
   - Recommended size: 800x600 pixels or larger
   - Landscape orientation works best with the header layout
   - JPEG format preferred for photos (smaller file size)

### Android URL Launcher Fix (2026-01-02)

Fixed tap-to-action features not working on Android 11+ devices:

1. **AndroidManifest.xml queries** (`android/app/src/main/AndroidManifest.xml`)
   - Added `<queries>` declarations required by Android 11+ (API 30+)
   - `https` / `http` schemes for opening websites
   - `tel` scheme for phone calls (DIAL intent)
   - `geo` scheme for opening maps
   - Without these declarations, `url_launcher` silently fails on newer Android versions

## Future Enhancements

### Google Places API for Parish Images

Consider integrating the Google Places API to automatically fetch real photos of parishes:

1. **Implementation approach**:
   - Use parish name + city to search for the place
   - Fetch place photos using the Place Photos API
   - Cache results to minimize API calls

2. **Requirements**:
   - Google Cloud Platform account
   - Places API enabled
   - API key with appropriate restrictions

3. **Estimated API costs** (as of 2025):
   - Place Search: $17 per 1,000 requests
   - Place Photos: $7 per 1,000 requests

4. **Alternative**: Continue using manual `image_url` entries in parish data for curated, cost-free images

## Session Log: 2026-01-05

### Updated Parish Data Format

Adapted the app to work with a revised `parishes.json` format:

1. **Parish model updates** (`lib/models/parish.dart`)
   - Added `parishId` field for unique parish identifiers
   - Added `adoration: List<String>` for adoration schedules
   - Added `eventsSummary` for upcoming events description
   - Changed JSON key from `www` to `website` (backward compatible)
   - Changed JSON key from `conf_times` to `confessions` (backward compatible)

2. **ParishDetailPage enhancements** (`lib/pages/parish_detail_page.dart`)
   - Added Adoration card (orange accent, sun icon) - only shown when data exists
   - Added Upcoming Events card (purple accent, event icon) - displays `events_summary`

3. **Adoration quick access** (`lib/main.dart`, `lib/pages/filtered_parish_list_page.dart`)
   - Added `ParishFilter.adoration` enum value
   - Connected Adoration button on HomePage to filtered list (no longer "Coming Soon")
   - Parishes with adoration schedules are now filterable and viewable

4. **Data format changes**
   - New JSON uses `website` instead of `www`
   - New JSON uses `confessions` instead of `conf_times`
   - New fields: `parish_id`, `adoration`, `events_summary`
   - Coordinates (`latitude`/`longitude`) are no longer present in the data
   - Map and distance features will need coordinates added to function

## Session Log: 2026-01-06

### Updated Parish Data and Coordinate Parsing

Updated the app to work with new parish data format containing 189 parishes:

1. **New coordinate format support** (`lib/models/parish.dart`)
   - Added `_parseLatitude()` and `_parseLongitude()` helper methods
   - Parses `lonlat` field format: `"longitude,latitude"` (e.g., `"-81.4749273,41.5212583"`)
   - Maintains backward compatibility with separate `latitude`/`longitude` fields
   - Map and distance features now work with the new data format

2. **Parish data update** (`data/parishes.json`)
   - Updated to 189 parishes (up from ~80)
   - New fields: `lonlat`, `bulletin_url`, `timestamp`
   - 188/189 parishes have coordinates
   - Removed `parishes.json.old` backup file

### Bulletin Button Feature

Added ability to view weekly parish bulletins:

1. **Parish model update** (`lib/models/parish.dart`)
   - Added `bulletinUrl` field (optional)
   - Maps from `bulletin_url` JSON key

2. **ParishDetailPage enhancement** (`lib/pages/parish_detail_page.dart`)
   - Added `_launchBulletin()` method to open bulletin URL in external browser
   - Added `_BulletinButton` widget with red accent color and article icon
   - Button appears after address card, before mass times (only if bulletin exists)
   - Opens PDF/bulletin in external browser app

3. **UI design**
   - Red accent color to distinguish from other action buttons
   - Article icon (`Icons.article`) with "Weekly Bulletin" title
   - Subtitle: "View the latest parish bulletin"
   - Open-in-new icon indicates external link

## Session Log: 2026-01-07

### Last Updated Indicator

Added data freshness indicator to parish detail page:

1. **Parish model update** (`lib/models/parish.dart`)
   - Added `lastUpdated` field (`DateTime?`)
   - Added `_parseTimestamp()` to parse `timestamp` JSON field (YYYY-MM-DD format)

2. **ParishDetailPage** (`lib/pages/parish_detail_page.dart`)
   - Added `_formatDate()` method formatting dates as MM-DD-YY
   - Displays "Data last updated: MM-DD-YY" at bottom of detail page

### Data Verification Feedback Form

Added user feedback form for verifying parish data accuracy:

1. **Feedback trigger** (`lib/pages/parish_detail_page.dart`)
   - "Is this information accurate?" button below last updated date
   - Opens bottom sheet with verification form

2. **`_DataFeedbackSheet` widget**
   - Two choice buttons: "Yes, it's accurate" / "No, there's an issue"
   - Issue category chips when reporting problems:
     - Mass Times, Confession Times, Adoration, Address, Phone Number, Website, Other
   - Optional text field for additional details
   - Submit button with loading state

3. **Email integration**
   - Submitting opens email client with pre-filled content
   - Subject: "Data Confirmed: [Parish]" or "Data Issue Report: [Parish]"
   - Body includes parish info, status, issues, and details

### Active Feedback System

Made all feedback forms functional with email integration:

1. **General Feedback** (`lib/main.dart`)
   - FeedbackPage now opens email client on submit
   - Subject: "MassGPT App Feedback"
   - Includes user feedback and optional reply email

2. **Parish Data Verification** (`lib/pages/parish_detail_page.dart`)
   - Opens email with parish details and reported issues
   - All feedback sent to `feedback@massgpt.org`

### Dark Mode for Filtered Lists

Added dark mode support to `FilteredParishListPage`:

1. **Theme integration** (`lib/pages/filtered_parish_list_page.dart`)
   - Added `themeNotifier` listener
   - Background, app bar, and text colors adapt to theme
   - Sort toggle button uses theme colors

2. **`_ParishCard` widget updates**
   - Accepts `cardColor`, `textColor`, `subtextColor` parameters
   - All card elements adapt to dark mode
   - Time chips use theme-aware colors

### About Page

Replaced info tooltip with About page:

1. **Homepage update** (`lib/main.dart`)
   - Changed bottom info section to "About this app" button
   - Tapping opens About page with slide-up animation

2. **`AboutPage` widget** (`lib/main.dart`)
   - App icon, name, and version display
   - Three placeholder cards: About This App, Credits, Contact
   - Full dark mode support
   - TODO comments for user to fill in details later

### Dynamic Parish Data Loading

Changed from static local JSON to dynamic remote loading:

1. **ParishService singleton** (`lib/services/parish_service.dart`)
   - Global `parishService` instance shared across all pages
   - Remote URL: `https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json`
   - Caches data after first successful load
   - 10-second timeout on network requests
   - Falls back to local `data/parishes.json` if network fails

2. **Updated pages to use service**:
   - `lib/main.dart` - HomePage
   - `lib/pages/research_parish_page.dart` - ResearchParishPage
   - `lib/pages/filtered_parish_list_page.dart` - FilteredParishListPage
   - `lib/pages/find_parish_near_me_page.dart` - FindParishNearMePage

3. **Added `http` package** (`pubspec.yaml`)
   - Version: `^1.2.0`
   - Used for fetching remote JSON data

### Local Caching and Offline Support

Enhanced data loading with local caching and offline handling:

1. **ParishService caching** (`lib/services/parish_service.dart`)
   - Caches parish JSON data locally using SharedPreferences
   - Loads cached data first for instant startup
   - Fetches fresh data from remote URL in background
   - `isUsingCachedData` flag indicates offline mode
   - `requiresInternet` flag for first-run without connection

2. **Removed bundled JSON** (`pubspec.yaml`)
   - `data/parishes.json` no longer bundled with APK
   - Data must be downloaded on first launch
   - Reduces app size and ensures fresh data

3. **"Internet Required" screen** (`lib/main.dart`)
   - `_buildRequiresInternetScreen()` widget
   - Shown on first launch without internet connection
   - WiFi-off icon with explanation message
   - "Try Again" button to retry connection

4. **Offline warning** (`lib/main.dart`)
   - `_showOfflineWarning()` displays orange snackbar
   - Shown when app uses cached data (couldn't reach server)
   - Message: "Offline mode - data may be out of date"

### Android Mailto Fix

Added mailto scheme for email feedback on Android 11+:

1. **AndroidManifest.xml queries**
   - Added `mailto` scheme with `SENDTO` action
   - Allows `url_launcher` to open email apps on Android 11+

## Session Log: 2026-01-07 (Evening)

### Custom Catholic Icons

Added custom SVG icons for Catholic-specific features using the flutter_svg package:

1. **Icon files** (`assets/icons/`)
   - `monstrance.svg` - Eucharistic monstrance icon for Adoration
   - `confession.svg` - Confessional booth icon for Confession/Reconciliation
   - Icons sourced from Noun Project (Ahmad Roaayala and Luis Prado)
   - Attribution text removed from SVG files
   - Cleaned up viewBox dimensions

2. **flutter_svg dependency** (`pubspec.yaml`)
   - Added `flutter_svg: ^2.0.10` for SVG rendering
   - Supports dynamic coloring and sizing

3. **CustomIcon widget** (`lib/widgets/custom_icons.dart`)
   - Centralized widget for rendering SVG icons
   - Factory constructors: `CustomIcon.monstrance()` and `CustomIcon.confession()`
   - Accepts `color` and `size` parameters for flexibility
   - Usage: `CustomIcon.monstrance(color: Colors.orange, size: 28)`

4. **HomePage integration** (`lib/main.dart`)
   - Updated `_QuickAccessButton` to accept `Widget` instead of `IconData`
   - Confession button uses `CustomIcon.confession()` (28px)
   - Adoration button uses `CustomIcon.monstrance()` (28px)
   - Increased icon sizes from 22px to 28px for better visibility

5. **ParishDetailPage integration** (`lib/pages/parish_detail_page.dart`)
   - Updated `_ScheduleCard` to accept `Widget` instead of `IconData`
   - Updated `_TappableInfoCard` to accept `Widget` instead of `IconData`
   - Confession Times card uses `CustomIcon.confession()` (26px)
   - Adoration card uses `CustomIcon.monstrance()` (26px)
   - Increased icon sizes from 20px to 26px for better visibility

6. **Icon size adjustments**
   - HomePage quick access buttons: 28px (27% larger than original 22px)
   - ParishDetailPage schedule cards: 26px (30% larger than original 20px)
   - Improved icon recognizability and visual hierarchy


## Session Log: 2026-01-08

### Nearest & Soonest Sorting

Added intelligent sorting that combines proximity and time to help users find the most convenient parishes:

1. **ScheduleParser utility** (`lib/utils/schedule_parser.dart`)
   - Parses schedule strings like "Sunday: 9:00AM, 11:00AM" into structured data
   - Supports day names (Monday-Sunday) and abbreviations (Mon, Tue, etc.)
   - Handles 12-hour format with AM/PM
   - Correctly converts to 24-hour time (noon, midnight edge cases)
   - Calculates next occurrence of each event from current time
   - `ScheduleEntry` class with `nextOccurrence()` and `minutesUntilNext()` methods
   - `findNextOccurrence()` finds soonest event from a list of schedules

2. **Enhanced FilteredParishListPage** (`lib/pages/filtered_parish_list_page.dart`)
   - Added `SortOrder.nearestAndSoonest` enum value
   - New `_calculateNextOccurrences()` method calculates minutes until next event for each parish
   - New `_calculateCompositeScore()` combines distance and time into a single score:
     - Distance weight: Each mile = ~15 minutes of "cost"
     - Composite score: 40% distance + 60% time priority
     - Lower score = better option (closer and sooner)
   - Updated `_toggleSortOrder()` to cycle through all three modes:
     - Nearest & Soonest → Nearest → A-Z → (repeat)
   - Default sort mode is now `nearestAndSoonest`

3. **UI enhancements**
   - Sort button shows icon and label based on current mode:
     - "Soonest" with schedule icon
     - "Nearest" with location icon
     - "A-Z" with alphabetical icon
   - Parish cards show time until next event when in "Soonest" mode:
     - "45 min" for events within the hour
     - "2h 30m" for events within 24 hours
     - "2 days" or "2d 5h" for events further out
   - Time badges use accent color matching the filter type

4. **Unit tests** (`test/schedule_parser_test.dart`)
   - Comprehensive test suite with 15 test cases
   - Tests parsing single/multiple times, AM/PM conversion
   - Tests noon and midnight edge cases
   - Tests next occurrence calculation across days
   - Tests wrapping to next week when event has passed
   - Tests finding soonest from multiple schedules
   - Tests graceful handling of invalid input

**Example use case:** User needs confession soon. Opens Confession filter, sees parishes sorted by composite score showing "2.1 mi, 45 min" is ranked above "1.5 mi, 2h 30m" because the first has confession starting sooner despite being slightly farther.


## Session Log: 2026-01-08 (App Rename)

### App Renamed: MassGPT → Introibo

Renamed the entire application from "MassGPT" to "Introibo" throughout the codebase:

1. **User-facing strings** (14 occurrences across 4 files)
   - `lib/main.dart` - App title, class names (`MassGPTApp` → `IntroiboApp`), window title, first-launch message, HomePage title, feedback email subject, email signatures, About page title and description
   - `lib/pages/parish_detail_page.dart` - Data feedback email signature
   - `README.md` - Project title, git repository URLs
   - `CLAUDE.md` - Project overview description

2. **Package identifiers** (all platforms)
   - `pubspec.yaml` - Package name: `massgpt_app_o1_preview` → `introibo`
   - `android/app/build.gradle` - namespace and applicationId: `com.example.massgpt_app_o1_preview` / `com.example.mass_gpt` → `com.example.introibo`
   - `android/app/src/main/AndroidManifest.xml` - android:label: `massgpt_app_o1_preview` → `Introibo`
   - `android/app/src/main/kotlin/` - Moved MainActivity.kt to new package structure (`com.example.introibo`)
   - `ios/Runner/Info.plist` - CFBundleDisplayName: `Massgpt App O1 Preview` → `Introibo`, CFBundleName: `massgpt_app_o1_preview` → `introibo`
   - `ios/Runner.xcodeproj/project.pbxproj` - PRODUCT_BUNDLE_IDENTIFIER: `com.example.massgptAppO1Preview` → `com.example.introibo`

3. **Test files**
   - `test/schedule_parser_test.dart` - Updated import path to use new package name (`package:introibo/...`)

4. **Cleanup**
   - Removed unused `lib/globals.dart` file that was causing build errors

5. **Intentionally preserved**
   - Email address remains `feedback@massgpt.org` (not changed to match app name)
   - Parish data source URL unchanged

**Verification:**
- `flutter pub get` completed successfully
- `flutter analyze` completed with 0 errors (112 info-level warnings for style/deprecations)
- All MassGPT references removed except for the preserved email address
