import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/utils/parish_palette.dart';

List<String> _parishNames() {
  final raw = File('export.demo.json').readAsStringSync();
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map((p) => (p['name'] as String).trim()).toList();
}

void main() {
  final names = _parishNames();

  test('every palette family has members, and light options exist', () {
    for (final family in GlassFamily.values) {
      final members = kGlassPalettes.where((p) => p.family == family);
      expect(members, isNotEmpty, reason: 'no palettes for $family');
      expect(members.length, greaterThanOrEqualTo(2),
          reason: '$family needs at least two members to vary within');
    }
    final light = kGlassPalettes.where((p) => p.isLight).length;
    expect(light, greaterThanOrEqualTo(8),
        reason: 'the pale palettes are a deliberate part of the range');
  });

  test('palette names are unique', () {
    final seen = kGlassPalettes.map((p) => p.name).toSet();
    expect(seen.length, kGlassPalettes.length);
  });

  test('selection is stable across calls', () {
    for (final n in names.take(40)) {
      expect(paletteForParish(n).name, paletteForParish(n).name);
    }
  });

  test('patron inference covers most of the real parish list', () {
    final inferred = names.where((n) => inferPatron(n).isInferred).length;
    final pct = 100 * inferred ~/ names.length;
    expect(pct, greaterThanOrEqualTo(90),
        reason: 'only $inferred/${names.length} ($pct%) parish names matched a rule');
  });

  test('named patrons land in the family you would expect', () {
    const cases = <String, GlassFamily>{
      'Saint Sebastian Parish': GlassFamily.martyr,
      'Our Lady of Lourdes Parish': GlassFamily.marian,
      'Immaculate Heart of Mary Church': GlassFamily.marian,
      'Saint Patrick Church': GlassFamily.religious,
      'Saints Peter and Paul': GlassFamily.apostolic,
      'Saint Augustine Church': GlassFamily.doctor,
      'Holy Spirit Catholic Church': GlassFamily.spirit,
      'Transfiguration Parish': GlassFamily.luminous,
      'Saint Michael the Archangel Parish': GlassFamily.angelic,
      'Saint Teresa of Avila Parish': GlassFamily.contemplative,
      // Must not read as the apostle Paul.
      'Saint Vincent de Paul Catholic Church': GlassFamily.religious,
      // Must not read as the angels.
      'Our Lady of Angels': GlassFamily.marian,
    };
    cases.forEach((name, family) {
      expect(inferPatron(name).family, family, reason: name);
    });
  });

  test('heritage is picked up where the name carries it', () {
    const cases = <String, SaintHeritage>{
      'Saint Patrick Church': SaintHeritage.irish,
      'Church of Saint Casimir / Parafia Sw. Kazimierza': SaintHeritage.polish,
      'Saint Vitus Parish - Župnija Svetega Vida': SaintHeritage.slovene,
      'Saint Paul Croatian Church (Hrvatska Crkva Sv. Pavla)': SaintHeritage.croatian,
      'Saint Emeric Parish': SaintHeritage.hungarian,
      'Saint John Nepomucene Parish': SaintHeritage.czech,
      'Saint Boniface, Cleveland': SaintHeritage.german,
      'Saint Anthony of Padua Church': SaintHeritage.italian,
      'Saint Thomas More Parish': SaintHeritage.english,
      'Saint Andrew Kim, Cleveland': SaintHeritage.korean,
      'Saint Teresa of Avila Parish': SaintHeritage.spanish,
      'Saint Therese Parish': SaintHeritage.french,
      'Saint Elizabeth Ann Seton Roman Catholic Parish': SaintHeritage.american,
      'Saint Cyprian Parish': SaintHeritage.african,
    };
    cases.forEach((name, heritage) {
      expect(inferPatron(name).heritage, heritage, reason: name);
    });
  });

  test('heritage steers the palette when a member carries that affinity', () {
    // Irish patrons should land on the one green that claims them.
    expect(paletteForParish('Saint Brendan Parish').name, 'Emerald & Copper');
    expect(paletteForParish('Saint Malachi Oratory').name, 'Emerald & Copper');
    // Polish martyrs onto the red that claims them.
    expect(paletteForParish('Saint Stanislaus').name, 'Rose & Pearl');
  });

  test('the ids the app actually seeds with carry no patron', () {
    // 181 of the 189 parishes have a parish_id like "0689", and the widgets seed
    // geometry with `parishId ?? name`. Inferring the patron from that seed
    // would silently kill this whole system for 96% of the diocese — which is
    // exactly the bug this guards. Palette inference must be given the *name*.
    final raw = File('export.demo.json').readAsStringSync();
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final ids = list
        .map((p) => p['parish_id'] as String?)
        .whereType<String>()
        .toList();
    expect(ids.length, greaterThan(150), reason: 'sanity: most parishes have ids');

    // Ids are a mix: numeric ones like "0689" match nothing, slug ones like
    // "saint-agnes-elyria-oh-ola" accidentally do. Either way they are the
    // wrong input — what matters is how far they diverge from the truth.
    var diverged = 0;
    for (final p in list) {
      final id = p['parish_id'] as String?;
      if (id == null) continue;
      final name = (p['name'] as String).trim();
      if (inferPatron(id).family != inferPatron(name).family) diverged++;
    }
    expect(diverged / ids.length, greaterThan(0.5),
        reason: 'seeding the palette from the id would change most parishes; '
            'callers must pass the name as `patron`');

    final byId = inferPatron('0689');
    final byName = inferPatron('Saint Sebastian Parish');
    expect(byId.isInferred, isFalse);
    expect(byName.isInferred, isTrue);
    expect(byName.family, GlassFamily.martyr);
  });

  test('every heritage a rule can produce is claimed inside its own family', () {
    // A palette's affinity only bites if it sits in the family the rules
    // actually route that heritage to. Declaring `slovene` on an apostolic
    // palette while every Slovene patron infers as a martyr is a silent no-op.
    final routed = <SaintHeritage, Set<GlassFamily>>{};
    for (final n in names) {
      final pr = inferPatron(n);
      if (pr.heritage != null) {
        routed.putIfAbsent(pr.heritage!, () => {}).add(pr.family);
      }
    }
    final dead = <String>[];
    routed.forEach((heritage, families) {
      for (final family in families) {
        final claimed = kGlassPalettes
            .any((p) => p.family == family && p.affinities.contains(heritage));
        if (!claimed) dead.add('${heritage.name} → ${family.name}');
      }
    });
    expect(dead, isEmpty,
        reason: 'heritage has no palette to steer toward: ${dead.join(', ')}');
  });

  test('no single palette swallows the diocese', () {
    final counts = <String, int>{};
    for (final n in names) {
      counts.update(paletteForParish(n).name, (v) => v + 1, ifAbsent: () => 1);
    }
    final worst = counts.values.reduce((a, b) => a > b ? a : b);
    expect(worst / names.length, lessThan(0.16),
        reason: 'palette spread: $counts');
  });

  test('unmatched names still spread across families', () {
    final unmatched = names.where((n) => !inferPatron(n).isInferred).toList();
    if (unmatched.length < 4) return; // too few to say anything
    final families = unmatched.map((n) => inferPatron(n).family).toSet();
    expect(families.length, greaterThanOrEqualTo(2));
  });
}
