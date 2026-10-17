/// Keeping the roster in the browser.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'roster.dart';

/// Keeps the roster on this device (localStorage on the web), so that the
/// names come back when the page is reloaded or opened again. It stays
/// until removed by hand (see docs/presentation.md).
abstract interface class RosterStore {
  /// Returns the kept roster, or null if there is none or it is unreadable.
  Future<Roster?> load();

  /// Keeps [roster], in place of any before it.
  Future<void> save(Roster roster);
}

/// [RosterStore] in shared_preferences, under `presentation.roster`.
class SharedPreferencesRosterStore implements RosterStore {
  SharedPreferencesRosterStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const key = 'presentation.roster';

  @override
  Future<Roster?> load() async {
    final json = await _preferences.getString(key);
    if (json == null) return null;
    try {
      return Roster.decode(json);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(Roster roster) =>
      _preferences.setString(key, roster.encode());
}

/// [RosterStore] in memory, for tests and the demo.
class MemoryRosterStore implements RosterStore {
  MemoryRosterStore([this.roster]);

  Roster? roster;

  @override
  Future<Roster?> load() async => roster;

  @override
  Future<void> save(Roster roster) async => this.roster = roster;
}
