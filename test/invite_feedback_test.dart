import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/widgets/invite_feedback_card.dart';

Map<String, dynamic> parishJson({Object? inviteFeedback = _absent}) => {
      'name': 'Saint Francis de Sales',
      'parish_id': '0123',
      'address': '4019 Manchester Rd',
      'city': 'Akron',
      'zip_code': '44319',
      if (!identical(inviteFeedback, _absent))
        'invite_feedback': inviteFeedback,
    };

const _absent = Object();

void main() {
  group('Parish.inviteFeedback', () {
    test('reads invite_feedback: true', () {
      expect(Parish.fromJson(parishJson(inviteFeedback: true)).inviteFeedback,
          isTrue);
    });

    test('reads invite_feedback: false', () {
      expect(Parish.fromJson(parishJson(inviteFeedback: false)).inviteFeedback,
          isFalse);
    });

    test('defaults to false when the field is absent (older cached JSON)', () {
      expect(Parish.fromJson(parishJson()).inviteFeedback, isFalse);
    });

    test('defaults to false for a non-boolean value', () {
      expect(Parish.fromJson(parishJson(inviteFeedback: 'yes')).inviteFeedback,
          isFalse);
    });
  });

  testWidgets('InviteFeedbackCard invites feedback and is tappable',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InviteFeedbackCard(
          accent: Colors.amber,
          cardColor: Colors.white,
          textColor: Colors.black,
          subtextColor: Colors.black54,
          onTap: () => taps++,
        ),
      ),
    ));

    expect(find.text('Do you know this parish?'), findsOneWidget);
    expect(find.text('Confirm or correct the times'), findsOneWidget);

    await tester.tap(find.byType(InviteFeedbackCard));
    expect(taps, 1);
  });
}
