import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/widgets/stained_glass_header.dart';

/// Stands in for a list card's small glass chip.
Widget _chip() => ParishGlassHero(
      seed: 'seed-1',
      borderRadius: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: StainedGlassHeader(seed: 'seed-1', overlayDarken: 0),
        ),
      ),
    );

/// Stands in for the detail page header: the same Hero, full-bleed, with the
/// parish name layered *outside* the flying subtree.
Widget _header() => const Stack(
      fit: StackFit.expand,
      children: [
        ParishGlassHero(
          seed: 'seed-1',
          overlayDarken: kHeaderOverlayDarken,
          child: StainedGlassHeader(
            seed: 'seed-1',
            overlayDarken: kHeaderOverlayDarken,
          ),
        ),
        Positioned(
          bottom: 18,
          left: 24,
          right: 24,
          child: Text('St. Example Parish', textDirection: TextDirection.ltr),
        ),
      ],
    );

/// A deliberately hostile header: the parish name nested *inside* the Hero,
/// the arrangement that used to put un-Materialed text in the flight overlay.
/// The shuttle builder is what has to neutralize it.
Widget _headerWithNestedText() => const ParishGlassHero(
      seed: 'seed-1',
      overlayDarken: kHeaderOverlayDarken,
      child: Stack(
        fit: StackFit.expand,
        children: [
          StainedGlassHeader(seed: 'seed-1', overlayDarken: kHeaderOverlayDarken),
          Positioned(
            bottom: 18,
            left: 24,
            right: 24,
            child: Text('St. Example Parish', textDirection: TextDirection.ltr),
          ),
        ],
      ),
    );

void main() {
  Widget app({Widget Function()? header}) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: SizedBox(height: 200, child: (header ?? _header)()),
                    ),
                  ),
                ),
                child: _chip(),
              ),
            ),
          ),
        ),
      );

  testWidgets('chip flies to the header and back without errors',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byType(ParishGlassHero));

    // Mid-flight
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byType(StainedGlassHeader), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the flying subtree carries no text', (tester) async {
    // Text inside a Hero renders in the overlay without a Material ancestor,
    // which is what painted the yellow double underline on the parish name.
    // The shuttle paints artwork only, so even a hero whose child contains
    // text flies clean.
    await tester.pumpWidget(app(header: _headerWithNestedText));
    await tester.tap(find.byType(ParishGlassHero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // The flight shuttle is parented to the Overlay, outside either route's
    // Scaffold — so every Text on screen must sit inside a Scaffold.
    final allText = find.byType(Text, skipOffstage: false);
    final textInScaffolds = find.descendant(
      of: find.byType(Scaffold, skipOffstage: false),
      matching: allText,
      skipOffstage: false,
    );
    expect(
      textInScaffolds.evaluate().length,
      allText.evaluate().length,
      reason: 'text is flying in the hero overlay',
    );
  });

  testWidgets('the painter fills whatever box it is given', (tester) async {
    // The painter is no longer wrapped in a FittedBox over a fixed 400x200
    // reference, so it depends on receiving real constraints. A zero size here
    // would render every chip blank without throwing.
    for (final box in const [Size(44, 44), Size(360, 180), Size(88, 88)]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: const StainedGlassHeader(seed: 'seed-1', overlayDarken: 0),
          ),
        ),
      ));
      expect(tester.takeException(), isNull, reason: '$box');
      final painted = tester.getSize(
        find.descendant(
          of: find.byType(StainedGlassHeader),
          matching: find.byType(CustomPaint),
        ).first,
      );
      expect(painted, box, reason: 'painter did not fill $box');
    }
  });

  testWidgets('flight uses a straight-line rect tween', (tester) async {
    await tester.pumpWidget(app());
    final hero = tester.widget<Hero>(find.byType(Hero));
    final tween = hero.createRectTween!(
      const Rect.fromLTWH(0, 0, 10, 10),
      const Rect.fromLTWH(100, 100, 200, 100),
    );
    // MaterialRectArcTween (the MaterialApp default) would bow off this line.
    expect(tween.transform(0.5), const Rect.fromLTWH(50, 50, 105, 55));
  });
}
