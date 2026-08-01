/// Dev-only entrypoint: identical to `main.dart` but with the Flutter driver
/// extension enabled, so tooling can tap widgets and take screenshots of the
/// running app.
///
/// Not shipped — release builds always target `lib/main.dart`.
///
///     flutter run -d linux -t lib/driver_main.dart
library;

import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
