/// How numbers are written on screen.
library;

/// Returns [score] zero-padded to five digits, e.g. 02100, as scores are
/// shown.
String formatScore(int score) => score.toString().padLeft(5, '0');

/// Returns the combo label for the [combo]th food in a row (1 or more) and
/// its score [multiplier], e.g. 3COMBO ×1.4. The count is joined to the
/// word, so that it does not read as 3 × 1.4.
String formatCombo(int combo, double multiplier) =>
    '${combo}COMBO ×${multiplier.toStringAsFixed(1)}';
