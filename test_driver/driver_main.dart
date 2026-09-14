/// Dev-only entrypoint: identical to `main.dart` but with the Flutter driver
/// extension enabled, so tooling can tap widgets and take screenshots of the
/// running app.
///
/// Not shipped — release builds always target `lib/main.dart`. It lives here
/// rather than in `lib/` because `flutter_driver` is a dev dependency, and the
/// analyzer rightly objects to shipped source importing one.
///
///     flutter run -d linux -t test_driver/driver_main.dart
library;

import 'package:flutter_driver/driver_extension.dart';

import 'package:parishfinder/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
