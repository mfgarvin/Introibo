import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/services/diocese_boundary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DioceseBoundary boundary;

  setUpAll(() async {
    boundary = DioceseBoundary();
    await boundary.load();
  });

  test('the outline asset is bundled and parses', () {
    expect(boundary.isLoaded, isTrue);
  });

  group('inside the diocese', () {
    // One town per county, so a county dropped from the generator fails here
    // rather than in the field.
    const towns = {
      'Cleveland (Cuyahoga)': LatLng(41.4993, -81.6944),
      'Painesville (Lake)': LatLng(41.7245, -81.2457),
      'Middlefield (Geauga)': LatLng(41.4617, -81.0740),
      'Elyria (Lorain)': LatLng(41.3683, -82.1076),
      'Medina (Medina)': LatLng(41.1387, -81.8632),
      'Stow (Summit)': LatLng(41.1595, -81.4404),
      'Wooster (Wayne)': LatLng(40.8051, -81.9351),
      'Loudonville (Ashland)': LatLng(40.6373, -82.2318),
    };

    towns.forEach((name, point) {
      test(name, () => expect(boundary.contains(point), isTrue));
    });
  });

  group('outside the diocese', () {
    // Sandusky and Castalia are the field reports that prompted this: both are
    // Diocese of Toledo, and both are closer to our parishes than parts of our
    // own Ashland County are. Kent is five miles from Stow and belongs to
    // Youngstown.
    const towns = {
      'Sandusky (Toledo)': LatLng(41.4489, -82.7079),
      'Castalia (Toledo)': LatLng(41.3939, -82.8035),
      'Norwalk (Toledo)': LatLng(41.2426, -82.6158),
      'Kent (Youngstown)': LatLng(41.1537, -81.3579),
      'Ravenna (Youngstown)': LatLng(41.1576, -81.2418),
      'Ashtabula (Youngstown)': LatLng(41.8651, -80.7898),
      'Canton (Youngstown)': LatLng(40.7989, -81.3784),
      'Mansfield (Toledo)': LatLng(40.7584, -82.5154),
      'Columbus': LatLng(39.9612, -82.9988),
      'Erie PA': LatLng(42.1292, -80.0851),
    };

    towns.forEach((name, point) {
      test(name, () => expect(boundary.contains(point), isFalse));
    });
  });

  test('every parish we ship falls inside the outline', () async {
    final raw = await File('export.demo.json').readAsString();
    final parishes = (json.decode(raw) as List)
        .map((entry) => Parish.fromJson(entry as Map<String, dynamic>))
        .where((parish) => parish.latitude != null && parish.longitude != null)
        .toList();

    expect(parishes, isNotEmpty);
    final strays = parishes
        .where((parish) =>
            boundary.contains(LatLng(parish.latitude!, parish.longitude!)) !=
            true)
        .map((parish) => '${parish.name} (${parish.city})')
        .toList();

    expect(strays, isEmpty,
        reason: 'a parish outside the outline means a county is missing');
  });

  test('an unloaded outline says "unknown", never "outside"', () {
    expect(DioceseBoundary().contains(const LatLng(41.4993, -81.6944)), isNull);
  });
}
