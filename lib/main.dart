/// The app's entry point.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'ranking/firebase_setup.dart';
import 'ranking/firestore_ranking_repository.dart';
import 'ranking/ranking_service.dart';
import 'ranking/ranking_storage.dart';

/// Starts the app: locks landscape, starts the ranking for the player in
/// the launch URL, and shows the title screen.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Honoured on mobile platforms; on the web LandscapeGuard covers portrait.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // The player ID comes with the URL of the guest's QR code.
  final ranking = RankingService(
    repository: FirestoreRankingRepository(lazyFirestore()),
    storage: SharedPreferencesRankingStorage(),
    launchUri: Uri.base,
  );
  unawaited(ranking.start());

  runApp(PendulumFeedingApp(ranking: ranking));
}
