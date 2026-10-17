/// The presentation page's entry point: the lightning talk and the live
/// ranking for the award, at /present/ (see docs/presentation.md).
///
///   flutter run -d web-server --web-port 5002 -t lib/presentation/main.dart
///
/// With `--dart-define=PRESENTATION_DEMO=true` it shows made-up players,
/// names and scores instead of Firestore's, to try the page.
library;

import 'package:flutter/material.dart';

import '../ranking/firebase_setup.dart';
import 'browser/browser.dart' as browser;
import 'presentation_fonts.dart';
import 'presentation_screen.dart';
import 'ranking_board.dart';
import 'roster.dart';
import 'roster_store.dart';
import 'standings.dart';
import 'standings_source.dart';

/// Whether to show [DemoStandings] instead of Firestore.
const _demo = bool.fromEnvironment('PRESENTATION_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final RosterStore rosterStore;
  final Stream<Standings> standings;
  if (_demo) {
    final demo = DemoStandings();
    rosterStore = MemoryRosterStore(demo.roster);
    standings = demo.standings;
  } else {
    rosterStore = SharedPreferencesRosterStore();
    standings = firestoreStandings(lazyFirestore());
  }

  try {
    await PresentationFonts.load();
  } on Object catch (error) {
    // Drawn in the game's font instead; names may then show as boxes.
    debugPrint('Font not loaded: $error');
  }

  Roster? roster;
  try {
    roster = await rosterStore.load();
  } on Object catch (error) {
    debugPrint('Roster not read: $error');
  }

  runApp(
    MaterialApp(
      title: '花嫁もぐもぐチャレンジの作り方',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: PresentationFonts.rounded),
      home: PresentationScreen(
        board: RankingBoard(standings),
        rosterStore: rosterStore,
        initialRoster: roster,
        droppedFiles: browser.droppedTextFiles(),
        pickFile: browser.pickTextFile,
        onUserGesture: browser.requestFullscreen,
      ),
    ),
  );
}
