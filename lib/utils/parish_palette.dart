import 'package:flutter/material.dart';

/// Colour selection for a parish's generative stained-glass window.
///
/// A parish's window is not coloured at random. The palette is chosen in two
/// stages from the parish's own name:
///
/// 1. **Family** — what the parish is named after. A Marian title draws from
///    the blues, a martyr from the reds, a doctor of the Church from the golds.
/// 2. **Member** — which palette within that family. Where the patron carries a
///    national tradition (an Irish monk, a Polish martyr, an Italian friar) the
///    palettes carrying that affinity are preferred; otherwise a stable hash of
///    the seed picks one.
///
/// The result is deterministic and offline — it needs nothing but the name we
/// already ship. Parishes with no recognisable patron still spread evenly
/// across every family, so nothing looks like a fallback.
///
/// This is evocative, not canonical: it is an identity system informed by
/// patronage, not a liturgical calendar. Where it departs from the vesture a
/// feast would actually use, it does so for visual range — apostles sit in
/// their own indigo family rather than swelling the reds, for instance.

/// Hue families. Each has three or four members spanning deep to pale.
enum GlassFamily {
  /// Mary under any title — blues.
  marian,

  /// Those who died for the faith — crimsons.
  martyr,

  /// The Twelve, Paul, and the evangelists — indigo and sea.
  apostolic,

  /// Doctors, bishops, confessors — ambers and golds.
  doctor,

  /// Founders, monastics, and the great religious orders — greens and earths.
  religious,

  /// Christological feasts and titles — white-golds.
  luminous,

  /// The Holy Spirit and Pentecost — flame.
  spirit,

  /// Mystics and penitents — violets.
  contemplative,

  /// The archangels and the angelic titles — pearl and silver.
  angelic,
}

/// National traditions legible in Cleveland/Akron's parish names — the city's
/// immigrant parishes are named with real specificity, and several still carry
/// the language in the title.
enum SaintHeritage {
  irish,
  german,
  polish,
  hungarian,
  czech,
  slovene,
  croatian,
  italian,
  french,
  spanish,
  english,
  american,
  korean,
  african,
}

@immutable
class GlassPalette {
  /// Human-readable name, for debugging and design review.
  final String name;
  final GlassFamily family;

  /// True for the pale palettes. Overlaid white header type needs a stronger
  /// scrim over these — see [scrimFor].
  final bool isLight;

  /// National traditions this palette suits. Empty means "suits any".
  final Set<SaintHeritage> affinities;

  /// Convention: deep → mid → bright are the field tones; accent carries the
  /// roundel; highlight is the smallest, brightest note.
  final Color deep;
  final Color mid;
  final Color bright;
  final Color accent;
  final Color highlight;

  const GlassPalette({
    required this.name,
    required this.family,
    required this.deep,
    required this.mid,
    required this.bright,
    required this.accent,
    required this.highlight,
    this.isLight = false,
    this.affinities = const {},
  });

  List<Color> get stops => [deep, mid, bright, accent, highlight];
}

/// Bottom-scrim opacity for a header drawn over [palette]. The parish name is
/// white; pale glass needs roughly half again as much scrim to hold it.
double scrimFor(GlassPalette palette) => palette.isLight ? 0.72 : 0.55;

/// Overall darkening applied across a header for [palette], mirroring
/// `StainedGlassHeader.overlayDarken`.
double headerDarkenFor(GlassPalette palette) => palette.isLight ? 0.52 : 0.45;

// ─────────────────────────────────────────────────────────────────────────────
// The palettes
// ─────────────────────────────────────────────────────────────────────────────

const List<GlassPalette> kGlassPalettes = [
  // ── Marian — blues ────────────────────────────────────────────────────────
  GlassPalette(
    name: 'Sapphire Vigil',
    family: GlassFamily.marian,
    affinities: {SaintHeritage.italian},
    deep: Color(0xFF0B2A4A), mid: Color(0xFF1E5F8A), bright: Color(0xFF3A7CA5),
    accent: Color(0xFFC9A227), highlight: Color(0xFFE8D7A1),
  ),
  GlassPalette(
    name: 'Chartres Blue',
    family: GlassFamily.marian,
    affinities: {SaintHeritage.french},
    deep: Color(0xFF10254F), mid: Color(0xFF26468C), bright: Color(0xFF4A6FC0),
    accent: Color(0xFFD9B44A), highlight: Color(0xFFF0E2AE),
  ),
  GlassPalette(
    name: 'Dawn Azure',
    family: GlassFamily.marian,
    isLight: true,
    deep: Color(0xFF4C7BA8), mid: Color(0xFF7BA6CE), bright: Color(0xFFA9C8E4),
    accent: Color(0xFFE4C877), highlight: Color(0xFFF6EEDA),
  ),
  GlassPalette(
    name: 'Silver Lily',
    family: GlassFamily.marian,
    isLight: true,
    affinities: {SaintHeritage.spanish, SaintHeritage.american},
    deep: Color(0xFF6B87A6), mid: Color(0xFF9CB3CA), bright: Color(0xFFC6D6E5),
    accent: Color(0xFFD8CBA8), highlight: Color(0xFFF6F2E8),
  ),

  // ── Martyr — crimsons ─────────────────────────────────────────────────────
  GlassPalette(
    name: 'Crimson & Saffron',
    family: GlassFamily.martyr,
    affinities: {SaintHeritage.slovene, SaintHeritage.korean, SaintHeritage.french},
    deep: Color(0xFF42060A), mid: Color(0xFF8A1622), bright: Color(0xFFC23842),
    accent: Color(0xFFE5A623), highlight: Color(0xFFF7D77C),
  ),
  GlassPalette(
    name: 'Burgundy & Rose',
    family: GlassFamily.martyr,
    affinities: {SaintHeritage.italian, SaintHeritage.english},
    deep: Color(0xFF3D0C11), mid: Color(0xFF7A1F2B), bright: Color(0xFFB23A48),
    accent: Color(0xFFE07A5F), highlight: Color(0xFFF2CC8F),
  ),
  GlassPalette(
    name: 'Vermilion Ember',
    family: GlassFamily.martyr,
    affinities: {SaintHeritage.african, SaintHeritage.hungarian, SaintHeritage.german},
    deep: Color(0xFF4A0F08), mid: Color(0xFF96271A), bright: Color(0xFFD14E2E),
    accent: Color(0xFFE8A33C), highlight: Color(0xFFF5D9A8),
  ),
  GlassPalette(
    name: 'Rose & Pearl',
    family: GlassFamily.martyr,
    isLight: true,
    affinities: {SaintHeritage.polish, SaintHeritage.czech},
    deep: Color(0xFF8E4A4E), mid: Color(0xFFB87478), bright: Color(0xFFDCA6A6),
    accent: Color(0xFFD9BC7E), highlight: Color(0xFFF7EDE4),
  ),

  // ── Apostolic — indigo and sea ────────────────────────────────────────────
  GlassPalette(
    name: 'Indigo & Pearl',
    family: GlassFamily.apostolic,
    deep: Color(0xFF161644), mid: Color(0xFF2F2E78), bright: Color(0xFF504DA8),
    accent: Color(0xFFD9D2C0), highlight: Color(0xFFF1ECDD),
  ),
  GlassPalette(
    name: 'Galilee Teal',
    family: GlassFamily.apostolic,
    affinities: {SaintHeritage.croatian, SaintHeritage.slovene},
    deep: Color(0xFF0B3142), mid: Color(0xFF1B5E7A), bright: Color(0xFF3A8DA8),
    accent: Color(0xFFE0A458), highlight: Color(0xFFF5D78A),
  ),
  GlassPalette(
    name: 'Net & Linen',
    family: GlassFamily.apostolic,
    isLight: true,
    deep: Color(0xFF4E6E86), mid: Color(0xFF7E9BAE), bright: Color(0xFFB3C9D6),
    accent: Color(0xFFDCC489), highlight: Color(0xFFF4F0E4),
  ),

  // ── Doctor — ambers and golds ─────────────────────────────────────────────
  GlassPalette(
    name: 'Scriptorium',
    family: GlassFamily.doctor,
    affinities: {SaintHeritage.african, SaintHeritage.french},
    deep: Color(0xFF3A2A0E), mid: Color(0xFF6B4C15), bright: Color(0xFFA2761F),
    accent: Color(0xFFE0B04A), highlight: Color(0xFFF6E3B0),
  ),
  GlassPalette(
    name: 'Honey & Ink',
    family: GlassFamily.doctor,
    isLight: true,
    affinities: {SaintHeritage.english, SaintHeritage.irish},
    deep: Color(0xFF7A5A22), mid: Color(0xFFA8823C), bright: Color(0xFFD2AE62),
    accent: Color(0xFFE8D08C), highlight: Color(0xFFF9F1DC),
  ),
  GlassPalette(
    name: 'Straw & Vellum',
    family: GlassFamily.doctor,
    isLight: true,
    affinities: {SaintHeritage.german},
    deep: Color(0xFF8A6E3A), mid: Color(0xFFB99B5E), bright: Color(0xFFDCC48E),
    accent: Color(0xFFCBB27A), highlight: Color(0xFFF7F1E2),
  ),

  // ── Religious — greens and earths ─────────────────────────────────────────
  GlassPalette(
    name: 'Forest & Ember',
    family: GlassFamily.religious,
    affinities: {SaintHeritage.american},
    deep: Color(0xFF1B3A2F), mid: Color(0xFF2F5D50), bright: Color(0xFF558C7A),
    accent: Color(0xFFD4A256), highlight: Color(0xFFE8C39E),
  ),
  GlassPalette(
    name: 'Emerald & Copper',
    family: GlassFamily.religious,
    affinities: {SaintHeritage.irish},
    deep: Color(0xFF0A2A1F), mid: Color(0xFF14593F), bright: Color(0xFF2E8B61),
    accent: Color(0xFFB8732D), highlight: Color(0xFFE6B888),
  ),
  GlassPalette(
    name: 'Sage & Linen',
    family: GlassFamily.religious,
    isLight: true,
    affinities: {SaintHeritage.french},
    deep: Color(0xFF5E7A63), mid: Color(0xFF8AA48C), bright: Color(0xFFB9CDB8),
    accent: Color(0xFFD3BE85), highlight: Color(0xFFF2EFE2),
  ),
  GlassPalette(
    name: 'Habit Brown',
    family: GlassFamily.religious,
    affinities: {SaintHeritage.italian, SaintHeritage.spanish},
    deep: Color(0xFF2B1D14), mid: Color(0xFF4E3626), bright: Color(0xFF7A5A3E),
    accent: Color(0xFFC08A45), highlight: Color(0xFFE6C79A),
  ),

  // ── Luminous — Christological white-golds ─────────────────────────────────
  GlassPalette(
    name: 'Gloria',
    family: GlassFamily.luminous,
    isLight: true,
    deep: Color(0xFF8A7433), mid: Color(0xFFB99D4E), bright: Color(0xFFE0C878),
    accent: Color(0xFFF0E0A8), highlight: Color(0xFFFBF6E4),
  ),
  GlassPalette(
    name: 'Paschal Pearl',
    family: GlassFamily.luminous,
    isLight: true,
    affinities: {SaintHeritage.spanish},
    deep: Color(0xFF7F8A93), mid: Color(0xFFA9B3B9), bright: Color(0xFFD3DADC),
    accent: Color(0xFFDFC98A), highlight: Color(0xFFF8F5EC),
  ),
  GlassPalette(
    name: 'Monstrance',
    family: GlassFamily.luminous,
    affinities: {SaintHeritage.italian},
    deep: Color(0xFF2E2408), mid: Color(0xFF5C4A12), bright: Color(0xFF96792A),
    accent: Color(0xFFE3C55C), highlight: Color(0xFFF8ECC0),
  ),

  // ── Spirit — flame ────────────────────────────────────────────────────────
  GlassPalette(
    name: 'Pentecost',
    family: GlassFamily.spirit,
    deep: Color(0xFF4A1206), mid: Color(0xFF8F2A0C), bright: Color(0xFFC9541D),
    accent: Color(0xFFEFA83A), highlight: Color(0xFFFBE0A6),
  ),
  GlassPalette(
    name: 'Tongues of Fire',
    family: GlassFamily.spirit,
    isLight: true,
    deep: Color(0xFFA85A2A), mid: Color(0xFFCE8A4E), bright: Color(0xFFE6B37C),
    accent: Color(0xFFF0D49A), highlight: Color(0xFFFCF1DE),
  ),

  // ── Contemplative — violets ───────────────────────────────────────────────
  GlassPalette(
    name: 'Vespers Violet',
    family: GlassFamily.contemplative,
    deep: Color(0xFF2A1A4A), mid: Color(0xFF503A75), bright: Color(0xFF7C5BA8),
    accent: Color(0xFFC9A227), highlight: Color(0xFFEED68A),
  ),
  GlassPalette(
    name: 'Midnight Plum',
    family: GlassFamily.contemplative,
    deep: Color(0xFF1E0A2A), mid: Color(0xFF4A1E5A), bright: Color(0xFF7A3E8E),
    accent: Color(0xFFE19A78), highlight: Color(0xFFF6D8B8),
  ),
  GlassPalette(
    name: 'Lilac Grisaille',
    family: GlassFamily.contemplative,
    isLight: true,
    affinities: {SaintHeritage.spanish, SaintHeritage.french},
    deep: Color(0xFF6E5E86), mid: Color(0xFF9789AC), bright: Color(0xFFC3B8D0),
    accent: Color(0xFFD6C08E), highlight: Color(0xFFF3EFE8),
  ),

  // ── Angelic — pearl and silver ────────────────────────────────────────────
  GlassPalette(
    name: 'Seraph',
    family: GlassFamily.angelic,
    isLight: true,
    deep: Color(0xFF5E6E7E), mid: Color(0xFF8FA0AE), bright: Color(0xFFC2CFD8),
    accent: Color(0xFFDCC68C), highlight: Color(0xFFF6F3EA),
  ),
  GlassPalette(
    name: 'Slate & Seafoam',
    family: GlassFamily.angelic,
    deep: Color(0xFF0F1F2A), mid: Color(0xFF2A4655), bright: Color(0xFF4F7C8A),
    accent: Color(0xFF8FD0BE), highlight: Color(0xFFD6EFE6),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Patron inference
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class PatronProfile {
  final GlassFamily family;
  final SaintHeritage? heritage;

  /// The rule that matched, for debugging and design review. Null when we fell
  /// back to hashing the name.
  final String? matched;

  const PatronProfile({required this.family, this.heritage, this.matched});

  bool get isInferred => matched != null;
}

class _Rule {
  final RegExp pattern;
  final GlassFamily family;
  final SaintHeritage? heritage;
  final String label;
  const _Rule(this.pattern, this.family, this.label, [this.heritage]);
}

RegExp _p(String source) => RegExp(source, caseSensitive: false);

/// Ordered most-specific first — the first match wins. Marian titles come
/// before everything, so "Our Lady of Angels" reads Marian rather than angelic
/// and "Mary Queen of the Apostles" reads Marian rather than apostolic.
final List<_Rule> _rules = [
  // ── Marian ────────────────────────────────────────────────────────────────
  _Rule(_p(r'guadalupe'), GlassFamily.marian, 'Our Lady of Guadalupe', SaintHeritage.spanish),
  _Rule(_p(r'lourdes|bernadette'), GlassFamily.marian, 'Lourdes', SaintHeritage.french),
  _Rule(_p(r'fatima'), GlassFamily.marian, 'Fátima'),
  _Rule(_p(r'mount carmel|mt\.? carmel'), GlassFamily.marian, 'Our Lady of Mount Carmel', SaintHeritage.italian),
  _Rule(_p(r'\bour lady\b|\bnotre dame\b'), GlassFamily.marian, 'A Marian title'),
  _Rule(_p(r'immaculate (conception|heart)'), GlassFamily.marian, 'The Immaculate Conception'),
  _Rule(_p(r'queen of (heaven|peace|the apostles|angels)'), GlassFamily.marian, 'Mary as Queen'),
  _Rule(_p(r'assumption|annunciation|visitation|nativity of the b'), GlassFamily.marian, 'A Marian feast'),
  _Rule(_p(r'mother of sorrows|holy rosary|\brosary\b'), GlassFamily.marian, 'A Marian devotion'),
  _Rule(_p(r'mary magdalene'), GlassFamily.contemplative, 'St Mary Magdalene, penitent'),
  _Rule(_p(r'\bmary\b|\bmarian\b|santa maria'), GlassFamily.marian, 'St Mary'),

  // ── Christological & Trinitarian ──────────────────────────────────────────
  _Rule(_p(r'holy spirit|holy ghost|pentecost'), GlassFamily.spirit, 'The Holy Spirit'),
  _Rule(_p(r'sacred heart|precious blood'), GlassFamily.spirit, 'The Sacred Heart'),
  _Rule(_p(r'holy (trinity|name|redeemer|family|cross)|blessed trinity'), GlassFamily.luminous, 'A title of the Lord'),
  _Rule(_p(r'sagrada familia'), GlassFamily.luminous, 'La Sagrada Familia', SaintHeritage.spanish),
  _Rule(_p(r'transfiguration|resurrection|ascension|epiphany|christ the king'), GlassFamily.luminous, 'A feast of the Lord'),
  _Rule(_p(r'corpus christi|blessed sacrament|divine word|prince of peace'), GlassFamily.luminous, 'A title of the Lord'),
  _Rule(_p(r'nativity of the lord|\bgesu\b|holy infant'), GlassFamily.luminous, 'The Nativity', SaintHeritage.italian),

  // ── Angels ────────────────────────────────────────────────────────────────
  _Rule(_p(r'michael|gabriel|raphael|archangel|\bangels?\b'), GlassFamily.angelic, 'The angels'),

  // ── Martyrs, with heritage where the name carries one ─────────────────────
  _Rule(_p(r'stanislaus|adalbert|kazimier|casimir|john cantius|hyacinth'), GlassFamily.martyr, 'A Polish patron', SaintHeritage.polish),
  _Rule(_p(r'nepomucene|wenceslaus|ludmila'), GlassFamily.martyr, 'A Bohemian martyr', SaintHeritage.czech),
  _Rule(_p(r'\bvitus\b|svetega vida'), GlassFamily.martyr, 'St Vitus', SaintHeritage.slovene),
  _Rule(_p(r'croatian|hrvatska'), GlassFamily.apostolic, 'A Croatian parish', SaintHeritage.croatian),
  _Rule(_p(r'elizabeth of hungary|elizabeth of hungry|emeric|ladislas|stephen of hungary'), GlassFamily.martyr, 'A Hungarian patron', SaintHeritage.hungarian),
  _Rule(_p(r'boniface|wendelin'), GlassFamily.martyr, 'A German missionary martyr', SaintHeritage.german),
  _Rule(_p(r'thomas more|john fisher|\balban\b'), GlassFamily.martyr, 'An English martyr', SaintHeritage.english),
  _Rule(_p(r'joan of arc'), GlassFamily.martyr, 'St Joan of Arc', SaintHeritage.french),
  _Rule(_p(r'cyprian|perpetua|felicit'), GlassFamily.martyr, 'A North African martyr', SaintHeritage.african),
  _Rule(_p(r'andrew kim'), GlassFamily.martyr, 'St Andrew Kim', SaintHeritage.korean),
  _Rule(_p(r'lucy|philomena|cecilia|agatha|\brocco\b|\bvitus\b'), GlassFamily.martyr, 'An Italian martyr', SaintHeritage.italian),
  _Rule(_p(r'sebastian|stephen|agnes|barbara|justin martyr|ignatius of antioch|cosmas|damian|clement|victor|lawrence|blaise|george|maximilian|holy martyrs|bishop & martyr'), GlassFamily.martyr, 'A martyr of the early Church'),
  _Rule(_p(r'john the baptist'), GlassFamily.martyr, 'St John the Baptist'),

  _Rule(_p(r'vincent de paul'), GlassFamily.religious, 'St Vincent de Paul', SaintHeritage.french),

  // ── Apostles & evangelists ────────────────────────────────────────────────
  _Rule(_p(r'peter and paul|peter & paul'), GlassFamily.apostolic, 'Ss Peter and Paul'),
  _Rule(_p(r'\bpeter\b|\bpaul\b|\bandrew\b|\bjames\b|\bbartholomew\b|\bmatthias\b|\bjude\b|\bsimon\b|\bphilip\b|\bbarnabas\b|\bthomas\b'), GlassFamily.apostolic, 'An apostle'),
  _Rule(_p(r'\bmatthew\b|\bmark\b|\bluke\b|john the evangelist'), GlassFamily.apostolic, 'An evangelist'),

  // ── Irish ─────────────────────────────────────────────────────────────────
  _Rule(_p(r'patrick|brendan|colman|columbkille|columba|bridget|brigid|malachi|kevin|\bmel\b|\bita\b|finbar'), GlassFamily.religious, 'An Irish saint', SaintHeritage.irish),

  // ── Founders, friars, monastics ───────────────────────────────────────────
  _Rule(_p(r'anthony of padua|francis of assis|\bclare\b|bonaventure|angela merici|john bosco|\brita\b'), GlassFamily.religious, 'An Italian religious', SaintHeritage.italian),
  _Rule(_p(r'benedict|scholastica|dominic|norbert|bruno'), GlassFamily.religious, 'A monastic founder'),
  _Rule(_p(r'ignatius of loyola|francis xavier|paschal baylon|dominic de guzman'), GlassFamily.religious, 'A Spanish religious', SaintHeritage.spanish),
  _Rule(_p(r'vincent de paul|julie billiart|colette|jeanne|louise de marillac'), GlassFamily.religious, 'A French religious', SaintHeritage.french),
  _Rule(_p(r'elizabeth ann seton|john neumann|cabrini|katharine drexel'), GlassFamily.religious, 'An American founder', SaintHeritage.american),

  // ── Mystics & contemplatives ──────────────────────────────────────────────
  _Rule(_p(r'teresa of avila|john of the cross'), GlassFamily.contemplative, 'A Carmelite mystic', SaintHeritage.spanish),
  _Rule(_p(r'therese|little flower'), GlassFamily.contemplative, 'St Thérèse of Lisieux', SaintHeritage.french),
  _Rule(_p(r'\bmonica\b|\bhelen[a]?\b|\bmartha\b|\banne?\b'), GlassFamily.contemplative, 'A holy woman'),

  // ── Doctors, bishops, confessors ──────────────────────────────────────────
  _Rule(_p(r'francis de sales|john vianney|martin of tours|\bdenis\b|\blouis\b|\bhilary\b'), GlassFamily.doctor, 'A French bishop', SaintHeritage.french),
  _Rule(_p(r'albert the great|\bhedwig\b|\bbruno\b'), GlassFamily.doctor, 'A German doctor', SaintHeritage.german),
  _Rule(_p(r'bede|anselm|\bedward\b|\brichard\b|\bcuthbert\b|\bdunstan\b'), GlassFamily.doctor, 'An English bishop', SaintHeritage.english),
  _Rule(_p(r'augustine'), GlassFamily.doctor, 'St Augustine of Hippo', SaintHeritage.african),
  _Rule(_p(r'ambrose|jerome|basil the great|leo the great|gregory|charles borromeo|athanasius|chrysostom'), GlassFamily.doctor, 'A doctor of the Church'),
  _Rule(_p(r'aloysius|\bnoel\b|\beugene\b|\bcolette\b|\bjoseph\b|christopher|nicholas|\brobert\b|\bwilliam\b|\bbernard\b|\bhubert\b'), GlassFamily.doctor, 'A confessor'),
];

/// Stable across runs and platforms — unlike `String.hashCode`, which Dart does
/// not guarantee between VM versions. A parish's window must not change colour
/// because the toolchain moved.
int stableHash(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

/// What a parish's name implies about its patron.
PatronProfile inferPatron(String parishName) {
  final name = parishName.toLowerCase();
  for (final rule in _rules) {
    if (rule.pattern.hasMatch(name)) {
      return PatronProfile(
        family: rule.family,
        heritage: rule.heritage,
        matched: rule.label,
      );
    }
  }
  // No recognisable patron — spread these evenly across every family rather
  // than pooling them in one, so a fallback never looks like a fallback.
  const families = GlassFamily.values;
  return PatronProfile(family: families[stableHash(name) % families.length]);
}

/// The palette for a parish, chosen from its name.
///
/// Heritage steers the choice in two ways. Where a member of the patron's
/// family claims that tradition, it wins outright — Irish patrons land on the
/// one green that claims them. Where no member of that family does (a family
/// only carries the affinities that suit its hues), heritage still salts the
/// hash, so two otherwise-identical names of different traditions diverge.
GlassPalette paletteForParish(String seed) {
  final profile = inferPatron(seed);
  final family = kGlassPalettes.where((p) => p.family == profile.family).toList();
  final pool = family.isEmpty ? kGlassPalettes : family;

  final withAffinity = profile.heritage == null
      ? const <GlassPalette>[]
      : pool.where((p) => p.affinities.contains(profile.heritage)).toList();
  final choices = withAffinity.isNotEmpty ? withAffinity : pool;

  final salt = profile.heritage == null ? '' : ':${profile.heritage!.name}';
  return choices[stableHash('$seed$salt') % choices.length];
}
