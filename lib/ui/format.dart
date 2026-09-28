/// Scores are shown zero-padded to five digits, e.g. 02100.
String formatScore(int score) => score.toString().padLeft(5, '0');
