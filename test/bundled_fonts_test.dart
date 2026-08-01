import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fonts are bundled under `assets/google_fonts/` so the app never contacts
/// fonts.gstatic.com (see `GoogleFonts.config.allowRuntimeFetching` in
/// main.dart). google_fonts locates them purely by filename: it builds
/// `'<family>-<variant>'` and looks for an asset ending in that string.
///
/// The failure mode this guards is silent. A misnamed file doesn't throw at
/// build time — google_fonts simply doesn't find it, and with runtime fetching
/// disabled the text renders in the platform default font instead. That is
/// easy to miss in review and obvious to users, so pin the exact names.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Family strings come from google_fonts itself: 'Inter' and, with no space,
  // 'CormorantGaramond'. Variant names come from its weight->filename map
  // (w400 Regular, w500 Medium, w600 SemiBold, w700 Bold, w800 ExtraBold).
  const expectedFonts = <String>[
    // Inter — body and UI. Weights used across lib/.
    'assets/google_fonts/Inter-Regular.ttf',
    'assets/google_fonts/Inter-Medium.ttf',
    'assets/google_fonts/Inter-SemiBold.ttf',
    'assets/google_fonts/Inter-Bold.ttf',
    'assets/google_fonts/Inter-ExtraBold.ttf',
    // Cormorant Garamond — display. Only w600 and w700 are used.
    'assets/google_fonts/CormorantGaramond-SemiBold.ttf',
    'assets/google_fonts/CormorantGaramond-Bold.ttf',
  ];

  test('every font weight the app uses is bundled as an asset', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    for (final font in expectedFonts) {
      expect(
        assets,
        contains(font),
        reason: '$font is missing from the asset bundle. google_fonts will '
            'fall back to the system font rather than failing loudly.',
      );
    }
  });

  test('bundled font files are real, non-empty TrueType data', () async {
    for (final font in expectedFonts) {
      final bytes = await rootBundle.load(font);
      expect(bytes.lengthInBytes, greaterThan(10000),
          reason: '$font looks truncated or is not a real font file.');

      // TrueType files start with the 0x00010000 sfnt version tag. A stray HTML
      // error page saved as .ttf — the exact thing a bad download produces —
      // would pass a size check but fail here.
      expect(bytes.getUint32(0), equals(0x00010000),
          reason: '$font is not valid TrueType data.');
    }
  });

  test('the OFL license text ships with the fonts', () async {
    for (final family in ['Inter', 'CormorantGaramond']) {
      final license =
          await rootBundle.loadString('assets/google_fonts/OFL-$family.txt');
      expect(license, contains('SIL OPEN FONT LICENSE'),
          reason: 'The OFL requires the license to travel with the fonts.');
    }
  });
}
