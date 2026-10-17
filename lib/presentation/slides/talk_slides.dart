/// The cover, the concept and theme slides, and the award page.
library;

import 'package:flutter/material.dart';

import '../presentation_assets.dart';
import '../slide_frame.dart';
import '../slide_style.dart';
import '../talk_content.dart';
import 'food_parade.dart';
import 'pendulum_demo.dart';
import 'slide_parts.dart';

/// The cover: "Lightning Talk" at the top left, the title over its
/// underline, and the date and the presenter.
class CoverSlide extends StatelessWidget {
  const CoverSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SlideBackground(),
        const Positioned.fill(child: FoodParade()),
        Positioned(
          left: 0,
          top: 0,
          width: 566,
          height: 176,
          child: Center(
            child: SlideText(TalkCover.kicker, style: SlideTextStyles.kicker),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 408,
          height: 192,
          child: Center(
            child: SlideText(
              TalkCover.title,
              style: SlideTextStyles.coverTitle,
            ),
          ),
        ),
        const Positioned(
          left: 346,
          top: 603,
          child: ShimmerRule(width: 1227, fade: RuleFade.both),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 630,
          height: 149,
          child: Center(
            child: SlideText(
              '${TalkCover.date}　${TalkCover.presenter}',
              style: SlideTextStyles.coverByline,
            ),
          ),
        ),
      ],
    );
  }
}

/// The concept: four points, and two guests playing on their phones.
class ConceptSlide extends StatelessWidget {
  const ConceptSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SlideBackground(),
        const SlideHeader(
          title: TalkConcept.title,
          message: TalkConcept.message,
        ),
        for (final (i, point) in TalkConcept.points.indexed)
          ...slideBullet(
            text: point,
            markerLeft: 101,
            textLeft: 174,
            centreY: 430.5 + 140 * i,
          ),
        const Positioned(
          left: 1138,
          top: 404,
          width: 319,
          height: 524,
          child: ShadowedImage(PresentationAssets.guestMan),
        ),
        const Positioned(
          left: 1457,
          top: 406,
          width: 395,
          height: 522,
          child: ShadowedImage(PresentationAssets.guestWoman),
        ),
      ],
    );
  }
}

/// The theme: the points, with the game's double pendulum swinging on the
/// right.
class ThemeSlide extends StatelessWidget {
  const ThemeSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SlideBackground(),
        const SlideHeader(title: TalkTheme.title, message: TalkTheme.message),
        for (final (i, point) in TalkTheme.points.indexed)
          ...slideBullet(
            text: point,
            markerLeft: 101,
            textLeft: 174,
            centreY: 430.5 + 120 * i,
          ),
        // Two lines each, the marker by the first.
        for (final (i, point) in TalkTheme.subPoints.indexed)
          ...slideBullet(
            text: point,
            markerLeft: 174,
            textLeft: 247,
            centreY: 713.5 + 187 * i,
            style: SlideTextStyles.subBullet,
            markerDy: -43.5,
          ),
        Positioned(
          // Square, about as big as the swing, by the points' middle.
          left: 1294,
          top: 335,
          width: 520,
          height: 520,
          child: Container(
            decoration: accentCard(
              SlidePalette.cardTeal,
              fill: SlidePalette.pendulumFill,
            ),
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(25)),
              child: PendulumDemo(),
            ),
          ),
        ),
      ],
    );
  }
}

/// The award: 表彰式, large and gold.
class AwardSlide extends StatelessWidget {
  const AwardSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SlideBackground(festive: true),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SlideText(
                TalkAward.gameTitle,
                style: SlideTextStyles.awardTalkTitle,
              ),
              const SizedBox(height: 40),
              const ShimmerRule(
                width: 1100,
                thickness: 6,
                fade: RuleFade.both,
                colors: (SlidePalette.gold, SlidePalette.goldLight),
                period: GoldText.period,
              ),
              const SizedBox(height: 24),
              GoldText('表彰式', style: SlideTextStyles.award),
              const SizedBox(height: 24),
              const ShimmerRule(
                width: 1100,
                thickness: 6,
                fade: RuleFade.both,
                colors: (SlidePalette.gold, SlidePalette.goldLight),
                period: GoldText.period,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
