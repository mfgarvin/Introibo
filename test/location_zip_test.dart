import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/services/location_service.dart';

Parish _parish({
  required String name,
  required String zip,
  double? lat,
  double? lon,
}) {
  return Parish(
    name: name,
    address: '1 Main St',
    city: 'Lakewood',
    zipCode: zip,
    phone: '',
    website: '',
    massTimes: const [],
    confTimes: const [],
    latitude: lat,
    longitude: lon,
  );
}

void main() {
  group('normalizeZip', () {
    test('accepts five digits', () {
      expect(LocationService.normalizeZip('44107'), '44107');
    });

    test('truncates ZIP+4 and strips punctuation', () {
      expect(LocationService.normalizeZip('44107-1234'), '44107');
      expect(LocationService.normalizeZip(' 44107 '), '44107');
    });

    test('rejects anything shorter than five digits', () {
      expect(LocationService.normalizeZip('4410'), isNull);
      expect(LocationService.normalizeZip(''), isNull);
      expect(LocationService.normalizeZip('abcde'), isNull);
    });
  });

  group('centroidForZip', () {
    final parishes = [
      _parish(name: 'A', zip: '44107', lat: 41.48, lon: -81.80),
      _parish(name: 'B', zip: '44107', lat: 41.50, lon: -81.78),
      _parish(name: 'C', zip: '44320', lat: 41.09, lon: -81.56),
      // No coordinates — must not drag the centroid toward zero.
      _parish(name: 'D', zip: '44107'),
    ];

    test('averages the parishes carrying that ZIP', () {
      final centre = LocationService.centroidForZip('44107', parishes);
      expect(centre, isNotNull);
      expect(centre!.latitude, closeTo(41.49, 0.0001));
      expect(centre.longitude, closeTo(-81.79, 0.0001));
    });

    test('ignores records with no coordinates', () {
      // Three records carry 44107 but only two have coordinates; a naive
      // count would pull the average a third of the way to (0, 0).
      final centre = LocationService.centroidForZip('44107', parishes)!;
      expect(centre.latitude, greaterThan(41.0));
    });

    test('matches a single-parish ZIP exactly', () {
      final centre = LocationService.centroidForZip('44320', parishes)!;
      expect(centre.latitude, closeTo(41.09, 0.0001));
      expect(centre.longitude, closeTo(-81.56, 0.0001));
    });

    test('handles ZIP+4 input', () {
      final centre = LocationService.centroidForZip('44320-0001', parishes)!;
      expect(centre.latitude, closeTo(41.09, 0.0001));
    });

    test('returns null for a ZIP with no parishes', () {
      expect(LocationService.centroidForZip('90210', parishes), isNull);
    });

    test('returns null for a malformed ZIP', () {
      expect(LocationService.centroidForZip('441', parishes), isNull);
    });
  });
}
