/// Scores are shown zero-padded to five digits, e.g. 02100.
String formatScore(int score) => score.toString().padLeft(5, '0');

/// The combo label: the foods in a row and the multiplier, e.g. 3COMBO ×1.4.
/// The count is joined to the word, so that it does not read as 3 × 1.4.
String formatCombo(int combo, double multiplier) =>
    '${combo}COMBO ×${multiplier.toStringAsFixed(1)}';
