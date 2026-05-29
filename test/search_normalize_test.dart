import 'package:flutter_test/flutter_test.dart';
import 'package:introibo/utils/search_normalize.dart';

/// Mirrors how the search uses it: normalize the field and the query, then
/// substring-match.
bool matches(String field, String query) =>
    normalizeForSearch(field).contains(normalizeForSearch(query));

void main() {
  group('Saint abbreviation flexibility', () {
    const sebastian = 'Saint Sebastian Parish';

    test('all singular spellings find a "Saint X" parish', () {
      for (final q in ['saint sebastian', 'st sebastian', 'st. sebastian', 'sebastian']) {
        expect(matches(sebastian, q), isTrue, reason: 'query "$q" should match');
      }
    });

    test('bare "st" / "st." while typing expand to saint', () {
      expect(normalizeForSearch('st'), 'saint');
      expect(normalizeForSearch('st.'), 'saint');
      expect(matches(sebastian, 'st'), isTrue);
      expect(matches(sebastian, 'st.'), isTrue);
    });

    test('"st x" is singular, not plural (regression)', () {
      expect(normalizeForSearch('st sebastian'), 'saint sebastian');
      expect(normalizeForSearch('st. sebastian'), 'saint sebastian');
    });

    test('every saint variant folds to one canonical token', () {
      for (final v in ['saint', 'saints', 'st', 'st.', 'sts', 'sts.', 'ss', 'ss.']) {
        expect(normalizeForSearch(v), 'saint', reason: '"$v" should canonicalize');
      }
    });

    test('plural-spelled parishes are reachable by any spelling', () {
      const ssPeter = 'Ss. Peter and Paul';
      const stsCosmas = 'Sts. Cosmas and Damian';
      for (final q in ['ss peter', 'ss. peter', 'sts peter', 'saints peter', 'saint peter', 'st peter']) {
        expect(matches(ssPeter, q), isTrue, reason: 'query "$q" should match Ss. Peter');
      }
      expect(matches(stsCosmas, 'st cosmas'), isTrue);
    });

    test('does not mangle ordinary words containing st', () {
      expect(normalizeForSearch('street'), 'street');
      expect(normalizeForSearch('first communion'), 'first communion');
      expect(normalizeForSearch('christ the king'), 'christ the king');
    });

    test('folds diacritics', () {
      expect(matches('Señor de los Milagros', 'senor'), isTrue);
      expect(matches('St. José', 'st jose'), isTrue);
    });
  });
}
