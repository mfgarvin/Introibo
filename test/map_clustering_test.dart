import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/utils/map_clustering.dart';

void main() {
  // Downtown Cleveland, a block apart; Lakewood; Akron.
  const cathedral = LatLng(41.5040, -81.6890);
  const nearby = LatLng(41.5048, -81.6880);
  const lakewood = LatLng(41.4820, -81.7980);
  const akron = LatLng(41.0814, -81.5190);
  final points = [cathedral, nearby, lakewood, akron];

  List<MapCluster<LatLng>> at(double zoom, [List<LatLng>? items]) =>
      clusterByScreenDistance<LatLng>(
        items ?? points,
        position: (p) => p,
        project: (ll) => const Epsg3857().latLngToPoint(ll, zoom),
        radius: 44,
      );

  test('street level: every pin stands alone', () {
    final c = at(17);
    expect(c.length, 4);
    expect(c.every((c) => c.isSingle), true);
  });

  test('city level: a block apart merges, Lakewood and Akron do not', () {
    final c = at(12);
    expect(c.length, 3);
    final merged = c.singleWhere((c) => !c.isSingle);
    expect(merged.members, unorderedEquals([cathedral, nearby]));
    // Drawn between the two, not on top of either.
    expect(merged.center.latitude, closeTo(41.5044, 1e-6));
  });

  test('whole diocese: Cleveland collapses, Akron is still apart', () {
    final c = at(9);
    expect(c.length, 2);
    expect(c.firstWhere((c) => c.members.contains(akron)).isSingle, true);
  });

  test('every item lands in exactly one cluster', () {
    final rng = math.Random(7);
    final many = [
      for (var i = 0; i < 190; i++)
        LatLng(41.0 + rng.nextDouble() * 0.7, -82.3 + rng.nextDouble() * 1.2),
    ];
    for (final zoom in [8.0, 10.0, 12.5, 15.0]) {
      final members = at(zoom, many).expand((c) => c.members).toList();
      expect(members.length, many.length, reason: 'zoom $zoom');
      expect(members.toSet().length, many.length, reason: 'zoom $zoom');
    }
  });

  test('no two marks are ever drawn within the radius', () {
    final rng = math.Random(11);
    final many = [
      for (var i = 0; i < 190; i++)
        LatLng(41.0 + rng.nextDouble() * 0.7, -82.3 + rng.nextDouble() * 1.2),
    ];
    for (final zoom in [8.0, 9.0, 10.0, 11.5, 13.0]) {
      math.Point<double> project(LatLng ll) =>
          const Epsg3857().latLngToPoint(ll, zoom);
      final drawn = [
        for (final c in clusterByScreenDistance<LatLng>(many,
            position: (p) => p, project: project, radius: 56, anchor: many[42]))
          project(c.center)
      ];
      for (var i = 0; i < drawn.length; i++) {
        for (var j = i + 1; j < drawn.length; j++) {
          expect(drawn[i].distanceTo(drawn[j]), greaterThan(56),
              reason: 'zoom $zoom, marks $i and $j');
        }
      }
    }
  });

  test('the anchor leads the first cluster and is drawn where it is', () {
    final c = clusterByScreenDistance<LatLng>(
      points,
      position: (p) => p,
      project: (ll) => const Epsg3857().latLngToPoint(ll, 12),
      radius: 44,
      anchor: nearby,
    );
    expect(c.first.members.first, nearby);
    expect(c.first.members, contains(cathedral));
    expect(c.first.center, nearby);
    expect(c.expand((c) => c.members).length, points.length);
  });

  test('same input order gives the same clusters', () {
    final a = at(10).map((c) => c.members).toList();
    final b = at(10).map((c) => c.members).toList();
    expect(a, b);
  });
}
