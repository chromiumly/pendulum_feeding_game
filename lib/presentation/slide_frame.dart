/// The slide stage and what every slide is drawn on.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../ui/assets.dart';
import 'slide_style.dart';

/// Lays out [child] in a fixed 1920x1080 slide, scaled to fit the screen
/// and letterboxed, so that slides are designed in one coordinate system
/// whatever the projector's resolution.
class SlideViewport extends StatelessWidget {
  const SlideViewport({super.key, required this.child});

  static const size = Size(1920, 1080);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      // FittedBox must be given tight constraints, or it would not scale up.
      child: SizedBox.expand(
        child: FittedBox(
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );
  }
}

/// The game's stage illustration, blurred and veiled in cream, behind every
/// slide. [festive] adds a warm gold glow and slow sparkles, for the cover
/// and the award.
class SlideBackground extends StatelessWidget {
  const SlideBackground({super.key, this.festive = false});

  final bool festive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 12.5,
            sigmaY: 12.5,
            tileMode: TileMode.mirror,
          ),
          child: Image.asset(GameAssets.background, fit: BoxFit.cover),
        ),
        const ColoredBox(color: SlidePalette.veil),
        if (festive) ...[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.1,
                colors: [Color(0x00FFE7A3), Color(0x40D9A93A)],
              ),
            ),
          ),
          const Sparkles(),
        ],
      ],
    );
  }
}

/// Small gold four-pointed stars that slowly twinkle, each in its own time.
class Sparkles extends StatefulWidget {
  const Sparkles({super.key, this.count = 64, this.seed = 7});

  final int count;

  /// Places the stars; the same seed gives the same sky.
  final int seed;

  @override
  State<Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<Sparkles>
    with SingleTickerProviderStateMixin {
  /// One twinkle of every star.
  late final _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final List<_Star> _stars = () {
    final random = math.Random(widget.seed);
    return [
      for (var i = 0; i < widget.count; i++)
        _Star(
          position: Offset(random.nextDouble(), random.nextDouble()),
          size: (10 + random.nextDouble() * 26) * 1.2,
          phase: random.nextDouble(),
          speed: 1 + random.nextInt(2),
        ),
    ];
  }();

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparklesPainter(_stars, _twinkle),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.position,
    required this.size,
    required this.phase,
    required this.speed,
  });

  /// Where the star is, as fractions of the width and height.
  final Offset position;

  /// From tip to tip [px].
  final double size;

  /// Where in its twinkle the star starts, from 0 to 1.
  final double phase;

  /// Twinkles per turn of the animation.
  final int speed;
}

class _SparklesPainter extends CustomPainter {
  _SparklesPainter(this.stars, this.twinkle) : super(repaint: twinkle);

  final List<_Star> stars;
  final Animation<double> twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final wave = math.sin(
        2 * math.pi * (twinkle.value * star.speed + star.phase),
      );
      // Bright for a moment, faint the rest of the time.
      final brightness = math.pow((wave + 1) / 2, 2).toDouble();
      if (brightness < 0.02) continue;
      final centre = Offset(
        star.position.dx * size.width,
        star.position.dy * size.height,
      );
      final radius = star.size / 2 * (0.6 + 0.4 * brightness);
      final paint = Paint()
        ..color = Color.lerp(
          SlidePalette.gold,
          SlidePalette.goldLight,
          brightness,
        )!.withValues(alpha: brightness);
      canvas.drawPath(_starPath(centre, radius), paint);
    }
  }

  /// A four-pointed star with curved sides.
  static Path _starPath(Offset c, double r) {
    final w = r * 0.18;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_SparklesPainter oldDelegate) =>
      oldDelegate.stars != stars;
}

/// [text] with a thin white outline, 2 to 4 px by its size, as in the
/// Figma design: it keeps the text crisp on the busy background.
///
/// The outline is a [RichText] under the [Text], so that a test finds the
/// text once.
class SlideText extends StatelessWidget {
  const SlideText(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  /// How far the outline reaches out of the letters of [fontSize] [px].
  static double outlineFor(double fontSize) => (fontSize / 20).clamp(2, 4);

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return Stack(
      children: [
        _outline(context, text, effective, textAlign),
        Text(text, style: style, textAlign: textAlign),
      ],
    );
  }
}

/// [text] as a white outline only, laid out as a [Text] of [style] would be
/// ([style] already merged with the default text style).
Widget _outline(
  BuildContext context,
  String text,
  TextStyle style, [
  TextAlign? textAlign,
  List<Shadow> shadows = const [],
]) {
  return RichText(
    textAlign: textAlign ?? TextAlign.start,
    textScaler: MediaQuery.textScalerOf(context),
    text: TextSpan(
      text: text,
      style: style.copyWith(
        shadows: shadows,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * SlideText.outlineFor(style.fontSize ?? 14)
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFFFFF),
      ),
    ),
  );
}

/// [text] in gold, over a white outline and a soft shadow so that it stands
/// out from the cream background, with one band of light sweeping across it
/// every [period]: a glint, then a pause.
class GoldText extends StatefulWidget {
  const GoldText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  /// One glint and the pause after it; the award's lines keep time with it.
  static const period = Duration(milliseconds: 3600);

  @override
  State<GoldText> createState() => _GoldTextState();
}

class _GoldTextState extends State<GoldText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: GoldText.period,
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return Stack(
      children: [
        _outline(context, widget.text, style, null, const [
          Shadow(
            color: Color(0x66805010),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ]),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // No light of its own: the moving glint is the only one.
            colors: [
              SlidePalette.goldDeep,
              SlidePalette.gold,
              SlidePalette.goldMid,
              SlidePalette.gold,
              SlidePalette.goldDeep,
            ],
            stops: [0, 0.3, 0.5, 0.7, 1],
          ).createShader(bounds),
          child: Text(
            widget.text,
            style: widget.style.copyWith(color: SlidePalette.gold),
          ),
        ),
        // The glint: a soft white band moving from the top left to the bottom
        // right in the first 40% of each period.
        AnimatedBuilder(
          animation: _sweep,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(
              (_sweep.value / 0.4).clamp(0.0, 1.0),
            );
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: const [
                  Color(0x00FFFFFF),
                  Color(0xD9FFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: const [0.4, 0.5, 0.6],
                transform: _Shift(-0.8 + 1.6 * t),
              ).createShader(bounds),
              child: child,
            );
          },
          child: RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              text: widget.text,
              style: style.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Moves a gradient sideways by [fraction] of the width of what it fills.
class _Shift extends GradientTransform {
  const _Shift(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}
