/// Normalize a search string so "St.", "St", and "Saint" all match each other
/// (likewise "Ss.", "Sts.", "Saints"). Lowercases, folds common diacritics,
/// expands the Saint abbreviations, and collapses whitespace.
String normalizeForSearch(String s) {
  var out = s.toLowerCase();

  // Fold common Latin-extended diacritics (parish names occasionally carry
  // them — e.g. "Señor", "José").
  const folds = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  folds.forEach((k, v) {
    out = out.replaceAll(k, v);
  });

  // Fold every Saint variant — "Saint", "Saints", "St", "St.", "Sts", "Sts.",
  // "Ss", "Ss." — to a single canonical "saint" token, so any spelling of the
  // query matches any spelling in the data (singular ↔ plural ↔ abbreviated).
  // The token may be followed by a space OR end the string, so partial queries
  // like "st" / "st." while typing still expand. Anchored with `\b` and the
  // trailing lookahead so it never touches words like "street" or "first".
  out = out.replaceAll(
    RegExp(r'\b(?:saints?|sts|ss|st)\.?(?=\s|$)'),
    'saint',
  );

  // Collapse runs of whitespace.
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}
