/// The root widget of the app.
library;

import 'package:flutter/material.dart';

import '../audio/sound_controller.dart';
import '../ranking/ranking_service.dart';
import '../ui/text_styles.dart';
import 'landscape_guard.dart';
import 'sound_scope.dart';
import 'title_screen.dart';

/// The app: theme, landscape guard and the title screen as home.
class PendulumFeedingApp extends StatelessWidget {
  const PendulumFeedingApp({super.key, this.ranking, this.sound});

  /// Records games and reports ranks; without it everyone plays as a guest.
  final RankingService? ranking;

  /// The sound on/off switch, music and effects; without it the app is
  /// silent and shows no sound button.
  final SoundController? sound;

  @override
  Widget build(BuildContext context) {
    return SoundScope(
      controller: sound,
      child: MaterialApp(
        title: '花嫁もぐもぐチャレンジ！',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFE88BA8),
          fontFamily: GameTextStyles.rounded,
        ),
        builder: (context, child) => LandscapeGuard(child: child!),
        home: TitleScreen(ranking: ranking),
      ),
    );
  }
}
