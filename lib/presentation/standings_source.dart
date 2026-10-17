/// Where the presentation page's standings come from.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'dummy_names.dart';
import 'roster.dart';
import 'standings.dart';

/// Follows bests/ and scores/ on Firestore, which every client may read
/// (see firestore.rules), and gives [Standings] whenever either changes.
///
/// If Firestore cannot be reached at all (e.g. no network at launch), it
/// tries again every [retryDelay]. Once connected, Firestore keeps the last
/// data when the connection drops, and the standings say so
/// ([Standings.isFromCache]).
Stream<Standings> firestoreStandings(
  Future<FirebaseFirestore> Function() firestore, {
  Duration retryDelay = const Duration(seconds: 5),
}) {
  late final StreamController<Standings> controller;
  final subscriptions = <StreamSubscription<Object?>>[];
  Timer? retry;
  var cancelled = false;

  List<PlayerBest>? bests;
  int? playCount;
  var bestsFromCache = false;
  var scoresFromCache = false;

  void emit() {
    if (bests == null || playCount == null) return;
    controller.add(
      Standings(
        bests: bests!,
        playCount: playCount!,
        isFromCache: bestsFromCache || scoresFromCache,
      ),
    );
  }

  Future<void> connect() async {
    final FirebaseFirestore db;
    try {
      db = await firestore();
    } on Object catch (error) {
      if (cancelled) return;
      controller.addError(error);
      retry = Timer(retryDelay, connect);
      return;
    }
    if (cancelled) return;
    subscriptions
      ..add(
        db.collection('bests').snapshots(includeMetadataChanges: true).listen((
          snapshot,
        ) {
          bests = [
            for (final doc in snapshot.docs)
              if (doc.data()['best'] case final num best)
                PlayerBest(key: doc.id, best: best.toInt()),
          ];
          bestsFromCache = snapshot.metadata.isFromCache;
          emit();
        }, onError: controller.addError),
      )
      ..add(
        db.collection('scores').snapshots(includeMetadataChanges: true).listen((
          snapshot,
        ) {
          playCount = snapshot.size;
          scoresFromCache = snapshot.metadata.isFromCache;
          emit();
        }, onError: controller.addError),
      );
  }

  controller = StreamController<Standings>(
    onListen: connect,
    onCancel: () async {
      cancelled = true;
      retry?.cancel();
      await Future.wait([for (final s in subscriptions) s.cancel()]);
    },
  );
  return controller.stream;
}

/// Made-up standings for trying the page without Firestore: [players]
/// players with made-up names, a tie for third, and every [interval] one of
/// them beats their best, so that the live ranking can be seen to move.
///
/// The names are in [roster]; the standings follow [standings].
class DemoStandings {
  DemoStandings({
    this.players = 12,
    this.interval = const Duration(seconds: 4),
    int seed = 1,
  }) : _random = math.Random(seed);

  final int players;
  final Duration interval;
  final math.Random _random;

  /// The demo players' keys, like real ones.
  late final List<String> _keys = [
    for (var i = 0; i < players; i++) Roster.keyOf('demo-player-$i'),
  ];

  /// Names for the demo players.
  late final roster = Roster({
    for (final (i, key) in _keys.indexed) key: dummyName(i),
  });

  /// Bests to start from: 8200, 7950, then two at 7600, then lower.
  List<int> get _startingBests => [
    8200,
    7950,
    7600,
    7600,
    for (var i = 4; i < players; i++) 7000 - i * 350,
  ];

  /// The standings now, then after every [interval].
  Stream<Standings> get standings async* {
    final bests = _startingBests.take(players).toList();
    var plays = players * 3;
    while (true) {
      yield Standings(
        bests: [
          for (final (i, key) in _keys.indexed)
            PlayerBest(key: key, best: bests[i]),
        ],
        playCount: plays,
      );
      await Future<void>.delayed(interval);
      final player = _random.nextInt(players);
      bests[player] = math.min(8700, bests[player] + 50 * _random.nextInt(8));
      plays++;
    }
  }
}
