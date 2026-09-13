// Parish data must not be allowed to age out inside a long-lived process.
//
// A cold start always fetches, but a phone rarely gives the app one: Android
// keeps the process cached and iOS keeps it suspended, so tapping the icon
// resumes rather than restarts. Before ParishService.refreshInterval existed,
// `_isLoaded` stayed true for the life of that process and the app would serve
// whatever it fetched on install — forever, with no indication anything was
// wrong. None of that is visible by looking at a screen, hence these.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parishfinder/services/parish_service.dart';

String _exportJson({String name = 'Saint Test Parish'}) => json.encode([
      {
        'name': name,
        'parish_id': '0001',
        'address': '1 Test Street',
        'city': 'Cleveland',
        'zip_code': '44114',
        'phone': '216-555-0100',
        'website': 'example.org',
        'latitude': 41.4995,
        'longitude': -81.6954,
        'timestamp': '2026-09-01',
        'schedules': {
          'mass': [
            {
              'day': 'sunday',
              'start': '09:00',
              'mass_date': null,
              'language': 'en',
              'notes': null,
              'cancelled': false,
            }
          ],
          'confession': <dynamic>[],
          'adoration': {'is_perpetual': false, 'times': <dynamic>[]},
        },
      }
    ]);

/// Seed the cache as if a fetch had succeeded [age] ago.
void _seedCache(Duration age, {String name = 'Saint Test Parish'}) {
  final fetchedAt = DateTime.now().subtract(age);
  SharedPreferences.setMockInitialValues({
    'cached_parishes_json': _exportJson(name: name),
    'cached_parishes_timestamp': fetchedAt.millisecondsSinceEpoch,
  });
}

/// A client that always fails, so a load falls back to the cache and the
/// cached timestamp — and therefore the age — survives.
http.Client _offlineClient(void Function() onCall) => MockClient((_) async {
      onCall();
      throw const SocketExceptionStub();
    });

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(parishService.resetForTest);

  group('staleness', () {
    test('data fetched a day ago is due for refresh but not yet stale',
        () async {
      _seedCache(const Duration(days: 1, minutes: 1));
      var calls = 0;
      ParishService.clientFactory = () => _offlineClient(() => calls++);

      await parishService.getParishes();

      expect(parishService.isUsingCachedData, isTrue);
      expect(parishService.dataAge!.inHours, greaterThanOrEqualTo(24));
      expect(parishService.isStale, isFalse,
          reason: 'a day old is refetch-worthy, not worth alarming the user');
    });

    test('data a week old is stale', () async {
      _seedCache(const Duration(days: 7, minutes: 1));
      ParishService.clientFactory = () => _offlineClient(() {});

      await parishService.getParishes();

      expect(parishService.isStale, isTrue);
    });

    test('fresh data is neither stale nor due', () async {
      _seedCache(const Duration(hours: 2));
      var calls = 0;
      ParishService.clientFactory = () => _offlineClient(() => calls++);

      await parishService.getParishes();
      final afterLoad = calls;
      await parishService.refreshIfStale();

      expect(parishService.isStale, isFalse);
      expect(calls, afterLoad,
          reason: 'two-hour-old data must not hit the network again');
    });
  });

  group('refresh on resume', () {
    test('a resume past the interval refetches and notifies', () async {
      _seedCache(const Duration(days: 2), name: 'Stale Parish');
      ParishService.clientFactory = () => _offlineClient(() {});
      await parishService.getParishes();
      expect(parishService.parishes.single.name, 'Stale Parish');

      // The network comes back, then the user reopens the app.
      var calls = 0;
      ParishService.clientFactory = () => MockClient((_) async {
            calls++;
            return http.Response(_exportJson(name: 'Fresh Parish'), 200);
          });
      var notified = 0;
      void listener() => notified++;
      parishService.addListener(listener);
      addTearDown(() => parishService.removeListener(listener));

      parishService.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await parishService.refreshIfStale();

      expect(calls, 1);
      expect(parishService.parishes.single.name, 'Fresh Parish');
      expect(parishService.isUsingCachedData, isFalse);
      expect(parishService.dataAge!.inMinutes, lessThan(1));
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('a resume inside the interval does not hit the network', () async {
      _seedCache(const Duration(hours: 1));
      ParishService.clientFactory = () => _offlineClient(() {});
      await parishService.getParishes();

      var calls = 0;
      ParishService.clientFactory = () => MockClient((_) async {
            calls++;
            return http.Response(_exportJson(), 200);
          });

      parishService.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await parishService.refreshIfStale();

      expect(calls, 0);
    });

    test('a failed background refresh keeps the parishes already loaded',
        () async {
      _seedCache(const Duration(days: 2), name: 'Cached Parish');
      ParishService.clientFactory = () => _offlineClient(() {});
      await parishService.getParishes();

      await parishService.refreshIfStale();

      expect(parishService.parishes.single.name, 'Cached Parish',
          reason: 'a dead network must never empty the screen');
      expect(parishService.isLoaded, isTrue);
      expect(parishService.isUsingCachedData, isTrue);
    });

    test('overlapping refreshes share one request', () async {
      _seedCache(const Duration(days: 2));
      ParishService.clientFactory = () => _offlineClient(() {});
      await parishService.getParishes();

      var calls = 0;
      ParishService.clientFactory = () => MockClient((_) async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return http.Response(_exportJson(), 200);
          });

      await Future.wait<void>([
        parishService.refreshIfStale(),
        parishService.refreshIfStale(),
        parishService.refreshIfStale(),
      ]);

      expect(calls, 1);
    });
  });

  test('getParishes does not wait on the background refresh', () async {
    _seedCache(const Duration(days: 2));
    ParishService.clientFactory = () => _offlineClient(() {});
    await parishService.getParishes();

    ParishService.clientFactory = () => MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return http.Response(_exportJson(), 200);
        });

    final watch = Stopwatch()..start();
    final parishes = await parishService.getParishes();
    watch.stop();

    expect(parishes, isNotEmpty);
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'the refresh is fire-and-forget; the caller gets cache now');
  });
}
