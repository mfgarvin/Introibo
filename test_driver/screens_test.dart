// Dev-only: drives the running app and saves screenshots to `screenshots/`
// (gitignored). Paired with `lib/driver_main.dart`.
//
//   flutter drive -t lib/driver_main.dart -d linux \
//     --driver=test_driver/screens_test.dart
//
// To shoot a state the live data doesn't currently contain — a cancelled Mass,
// say — serve a doctored copy of the export and point the app at it for the
// run, reverting both edits afterwards:
//
//   python3 -m http.server 8765 --bind 127.0.0.1   # over a patched export.json
//   # ParishService._remoteUrl -> http://127.0.0.1:8765/export.json
//   # linux/my_application.cc  -> gtk_window_set_default_size(window, 430, 880)
//
// The window size is what makes the shots phone-shaped; at the stock 1280x720
// the cards lay out as they would on a tablet.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> shoot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  final file = File('screenshots/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('wrote ${file.path} (${bytes.length} bytes)');
}

void main() async {
  final driver = await FlutterDriver.connect();
  try {
    // main() does its async init (theme, diocese boundary) before runApp, and
    // the driver connects to a paused isolate — so the first command can land
    // before there is a root widget to talk to. Retry until there is one.
    for (var i = 0; i < 30; i++) {
      try {
        await driver.waitUntilNoTransientCallbacks(
            timeout: const Duration(seconds: 5));
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    // The data load is a network round trip; wait for the home content.
    await driver.waitFor(find.byType('TextField'),
        timeout: const Duration(seconds: 30));
    await shoot(driver, '01_home');

    // Into the Mass Times list, which shows the standing schedule as
    // day-grouped chips once it is sorted A-Z.
    await driver.tap(find.text('Mass Times'));
    await Future<void>.delayed(const Duration(seconds: 3));
    await shoot(driver, '07_list_soonest');
    await driver.tap(find.text('A\u2013Z'));
    await Future<void>.delayed(const Duration(seconds: 3));
    await shoot(driver, '08_list_az');
  } finally {
    await driver.close();
  }
}
