import 'package:flutter/material.dart';

import '../ui/text_styles.dart';
import 'landscape_guard.dart';
import 'title_screen.dart';

class PendulumFeedingApp extends StatelessWidget {
  const PendulumFeedingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '花嫁もぐもぐチャレンジ！',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE88BA8),
        fontFamily: GameTextStyles.rounded,
      ),
      builder: (context, child) => LandscapeGuard(child: child!),
      home: const TitleScreen(),
    );
  }
}
