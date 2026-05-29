import 'package:package_info_plus/package_info_plus.dart';

/// Loaded once at startup by `main()` so About / Settings can read it
/// synchronously. Populated from the native bundle, which on Android reflects
/// the git-derived versionCode set in `android/app/build.gradle`.
class AppVersion {
  static String version = '?';
  static String buildNumber = '?';

  static Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    buildNumber = info.buildNumber;
  }

  /// Display form: "1.0.0 build 43" (or just "1.0.0" if no build number).
  static String get display =>
      buildNumber.isEmpty || buildNumber == '?' ? version : '$version build $buildNumber';
}
