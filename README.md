# Introibo

A Flutter mobile app for finding Catholic parishes and Mass times in the Cleveland/Akron, Ohio area.

## Features

### Search & Discovery
- **Instant Search** - Find parishes by name, city, or ZIP code with real-time autocomplete
- **Nearby Parishes** - GPS-powered list of the 10 closest parishes with distance badges
- **Interactive Map** - OpenStreetMap view with custom markers for all 188+ parishes

### Quick Filters
- **Mass Times** - View all parishes with scheduled Masses
- **Confession** - Find parishes offering confession times
- **Adoration** - Locate adoration opportunities
- **Sorting** - Toggle between nearest-first or alphabetical order

### Parish Details
- **Mass & Confession Schedules** - Complete weekly schedules
- **Weekly Bulletin** - Direct link to PDF bulletins
- **Contact Actions** - Tap to call, get directions, or visit website

### Personalization
- **Favorites** - Save parishes for quick access
- **Dark Mode** - Full light/dark theme support
- **Offline Mode** - Works without internet using cached data

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.5.1+)
- Android Studio or Xcode (for mobile builds)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/introibo.git
cd introibo

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Build Commands

```bash
flutter run -d linux        # Linux desktop
flutter run -d chrome        # Web browser
flutter run -d android       # Android device/emulator
flutter build apk            # Android release APK
flutter build ios            # iOS (requires macOS)
```

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.5+ |
| Language | Dart |
| Maps | flutter_map + OpenStreetMap |
| Location | Geolocator + Permission Handler |
| Caching | SharedPreferences |
| Images | Cached Network Image |

## Project Structure

```
lib/
├── main.dart                 # App entry, theme, HomePage
├── models/
│   └── parish.dart           # Parish data model
├── pages/
│   ├── parish_detail_page.dart
│   ├── find_parish_near_me_page.dart
│   └── filtered_parish_list_page.dart
└── services/
    └── parish_service.dart   # Remote data + caching
```

## Data Source

Parish data is loaded from a remote JSON endpoint with local caching for offline use. The dataset includes 188+ parishes in the Cleveland/Akron area with GPS coordinates, schedules, contact info, and bulletin links.

## Contributing

Contributions are welcome. Please open an issue first to discuss proposed changes.

## License

This project is licensed under the [PolyForm Noncommercial 1.0.0](LICENSE) license. You may use, modify, and distribute this software for any noncommercial purpose.
