import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// One mark on the map: a lone item, or several close enough on screen that
/// drawing each would stack pins into an unreadable pile.
class MapCluster<T> {
  final List<T> members;

  /// Where to draw it — the mean of the members' positions, so a bubble sits
  /// in the middle of what it stands for rather than on its first member. The
  /// anchor's cluster is the exception: it is drawn on the anchor.
  final LatLng center;

  const MapCluster(this.members, this.center);

  bool get isSingle => members.length == 1;
}

/// Group [items] so that no two marks are drawn within [radius] pixels of
/// one another.
///
/// Two passes. First, greedy: each item not yet claimed seeds a cluster and
/// claims every unclaimed item within [radius] of the seed. Then, because a
/// cluster is drawn at its members' mean and that can drift towards a
/// neighbour, clusters whose drawn centres are still within [radius] merge,
/// repeatedly, until none are. A grid would be cheaper but splits two
/// churches either side of a cell line however close they are; at under 200
/// points this costs nothing.
///
/// Order-stable: feed the items in a fixed order (the service's, not a
/// distance sort) or clusters reshuffle as the map pans.
///
/// [anchor], if given, seeds first and its cluster is drawn on the anchor
/// itself rather than at the mean — the map's selected parish, which has to
/// stay exactly where its card says it is, with whatever it hides counted on
/// it rather than piled beside it.
///
/// [project] maps a position to pixels at the zoom being drawn — pass a
/// projection at the camera's zoom. It is pan-independent, so the result only
/// needs recomputing when the zoom changes.
List<MapCluster<T>> clusterByScreenDistance<T>(
  List<T> items, {
  required LatLng Function(T) position,
  required math.Point<double> Function(LatLng) project,
  required double radius,
  T? anchor,
}) {
  final ordered = [
    if (anchor != null) anchor,
    for (final i in items)
      if (i != anchor) i,
  ];
  final points = [for (final i in ordered) project(position(i))];
  final r2 = radius * radius;

  bool near(math.Point<double> a, math.Point<double> b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return dx * dx + dy * dy <= r2;
  }

  // Pass 1: greedy, around seeds. Groups hold indices into [ordered].
  final claimed = List<bool>.filled(ordered.length, false);
  final groups = <List<int>>[];
  for (var i = 0; i < ordered.length; i++) {
    if (claimed[i]) continue;
    claimed[i] = true;
    final g = [i];
    for (var j = i + 1; j < ordered.length; j++) {
      if (!claimed[j] && near(points[i], points[j])) {
        claimed[j] = true;
        g.add(j);
      }
    }
    groups.add(g);
  }

  final anchored = anchor != null;
  math.Point<double> drawnAt(int g) {
    final members = groups[g];
    if (anchored && members.first == 0) return points[0];
    var x = 0.0, y = 0.0;
    for (final m in members) {
      x += points[m].x;
      y += points[m].y;
    }
    return math.Point(x / members.length, y / members.length);
  }

  // Pass 2: merge any two marks still drawn too close. Merging into the
  // earlier group keeps the anchor's group first.
  var merged = true;
  while (merged) {
    merged = false;
    final at = [for (var g = 0; g < groups.length; g++) drawnAt(g)];
    outer:
    for (var a = 0; a < groups.length; a++) {
      for (var b = a + 1; b < groups.length; b++) {
        if (near(at[a], at[b])) {
          groups[a].addAll(groups.removeAt(b));
          merged = true;
          break outer;
        }
      }
    }
  }

  return [
    for (final g in groups)
      MapCluster<T>(
        [for (final i in g) ordered[i]],
        anchored && g.first == 0
            ? position(ordered[0])
            : LatLng(
                g.map((i) => position(ordered[i]).latitude).reduce((a, b) => a + b) /
                    g.length,
                g.map((i) => position(ordered[i]).longitude).reduce((a, b) => a + b) /
                    g.length,
              ),
      ),
  ];
}
