/// The ranking on the presentation page: live, or frozen for the award.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'standings.dart';

/// Follows the [Standings] as they come in, and can freeze them, so that
/// the ranks stand still while they are announced.
///
/// Entering the ranking page freezes them at that moment ([freezeOnEnter]);
/// once frozen they stay so, wherever the pages go, until [toggleFreeze].
class RankingBoard extends ChangeNotifier {
  /// Follows [standings] from now until [dispose].
  RankingBoard(Stream<Standings> standings, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _subscription = standings.listen(_receive, onError: _fail);
  }

  final DateTime Function() _clock;
  late final StreamSubscription<Standings> _subscription;

  Standings? _live;
  Standings? _frozen;
  bool _isFrozen = false;
  DateTime? _frozenAt;
  bool _hasError = false;

  /// The latest standings, or null before the first.
  Standings? get live => _live;

  /// Whether the shown standings are frozen.
  bool get isFrozen => _isFrozen;

  /// When the standings were frozen, or null while live.
  DateTime? get frozenAt => _frozenAt;

  /// What to show: the frozen standings, or the latest while live. Null
  /// until the first arrive, also when frozen before then.
  Standings? get shown => _isFrozen ? _frozen : _live;

  /// Whether the last attempt to follow the standings failed. Cleared by
  /// the next standings.
  bool get hasError => _hasError;

  /// Freezes the standings if they are live: for the ranking page, which
  /// is entered just before the ranks are announced.
  void freezeOnEnter() {
    if (!_isFrozen) _freeze();
  }

  /// Freezes live standings, or lets frozen ones follow the latest again.
  void toggleFreeze() {
    if (_isFrozen) {
      _isFrozen = false;
      _frozen = null;
      _frozenAt = null;
      notifyListeners();
    } else {
      _freeze();
    }
  }

  /// Freezes at the latest standings; if none have come yet, at the first.
  void _freeze() {
    _isFrozen = true;
    _frozen = _live;
    _frozenAt = _clock();
    notifyListeners();
  }

  void _receive(Standings standings) {
    _live = standings;
    _hasError = false;
    if (_isFrozen && _frozen == null) _frozen = standings;
    notifyListeners();
  }

  void _fail(Object error) {
    debugPrint('Ranking failed: $error');
    _hasError = true;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
