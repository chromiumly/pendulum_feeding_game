/// The roster: which display name goes with which player, for the ranking
/// on the presentation page.
///
/// Pure Dart (no Flutter), so that tool/ranking/player_ids.dart writes the
/// file with the same code that reads it.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Display names by player key: the SHA-256 hex of the player ID, as the
/// documents in bests/ are keyed (see `FirestoreRankingRepository.bestKey`).
/// The roster never holds the IDs themselves, which are secrets: a roster
/// left behind on a borrowed PC gives away names, not a way to play as
/// someone.
class Roster {
  Roster(Map<String, String> names) : _names = Map.unmodifiable(names);

  /// Reads a roster file written by [encode]. Throws a [FormatException] if
  /// [json] is not one.
  factory Roster.decode(String json) {
    final Object? data;
    try {
      data = jsonDecode(json);
    } on FormatException {
      throw const FormatException('Not a roster file.');
    }
    if (data is! Map || data['format'] != format || data['names'] is! Map) {
      throw const FormatException('Not a roster file.');
    }
    final names = <String, String>{};
    for (final MapEntry(:key, :value) in (data['names'] as Map).entries) {
      if (key is! String || !_keyPattern.hasMatch(key) || value is! String) {
        throw const FormatException('A roster entry is malformed.');
      }
      names[key] = value;
    }
    return Roster(names);
  }

  /// Marks a roster file, so that another JSON file is turned away.
  static const format = 'pendulum-feeding-game-roster';

  static final _keyPattern = RegExp(r'^[0-9a-f]{64}$');

  final Map<String, String> _names;

  /// Returns the player key of [playerId]: the SHA-256 hex of the ID.
  static String keyOf(String playerId) =>
      sha256.convert(utf8.encode(playerId)).toString();

  /// How many players have a name.
  int get length => _names.length;

  /// Returns the display name of the player with [key], or null if the
  /// roster has none.
  String? nameOf(String key) => _names[key];

  /// Returns the roster as a roster file.
  String encode() =>
      const JsonEncoder.withIndent('  ')
          .convert({'format': format, 'names': _names});
}
