/// The pieces the talk's slides are made of, laid out as in the Figma
/// design on the 1920x1080 slide.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../slide_frame.dart';
import '../slide_style.dart';

/// Which ends of a [ShimmerRule] fade out.
enum RuleFade {
  /// Only the right: under a title on the left.
  right,

  /// Both: under a centred title.
  both,
}

/// The orange-gold underline of the titles: it fades out towards [fade]'s
/// ends, being about gone at its own [width], and a highlight sweeps along
/// it from left to right as on the game's play-count bonus gauge
/// (BonusGaugeBar). [colors] and [period] make it the award's gold lines.
class ShimmerRule extends StatefulWidget {
  const ShimmerRule({
    super.key,
    required this.width,
    this.thickness = 12,
    this.fade = RuleFade.right,
    this.colors = const (SlidePalette.ruleDeep, SlidePalette.ruleLight),
    this.period = const Duration(milliseconds: 2400),
  });

  final double width;
  final double thickness;
  final RuleFade fade;

  /// The line's colour on the left and along it.
  final (Color, Color) colors;

  /// One sweep and the pause after it.
  final Duration period;

  @override
  State<ShimmerRule> createState() => _ShimmerRuleState();
}

class _ShimmerRuleState extends State<ShimmerRule>
    with SingleTickerProviderStateMixin {
  /// One sweep along the line, then a pause before the next, as on the
  /// gauge.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.thickness),
        painter: _RulePainter(_sweep, widget.fade, widget.colors),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  _RulePainter(this.sweep, this.fade, this.colors) : super(repaint: sweep);

  final Animation<double> sweep;
  final RuleFade fade;
  final (Color, Color) colors;

  /// How much of the line shows along it, at [0, 0.3, 0.7, 1] of its
  /// length: whole near the start (or the middle), gone at the end(s).
  List<Color> get _alphas => switch (fade) {
    RuleFade.right => const [
      Color(0xFF000000),
      Color(0xFF000000),
      Color(0x66000000),
      Color(0x00000000),
    ],
    RuleFade.both => const [
      Color(0x00000000),
      Color(0xFF000000),
      Color(0xFF000000),
      Color(0x00000000),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final line = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.height / 2),
    );
    canvas.saveLayer(bounds, Paint());

    // Deep on the left and lighter along it.
    canvas.drawRRect(
      line,
      Paint()
        ..shader = LinearGradient(colors: [colors.$1, colors.$2])
            .createShader(bounds),
    );

    // The highlight: a soft white band that moves from left to right during
    // the first 60% of each cycle and waits outside the line for the rest.
    final t = Curves.easeInOut.transform((sweep.value / 0.6).clamp(0.0, 1.0));
    final band = size.width * 0.22;
    final left = -band + (size.width + band) * t;
    final bandRect = Rect.fromLTWH(left, 0, band, size.height);
    canvas
      ..save()
      ..clipRRect(line)
      ..drawRect(
        bandRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)],
          ).createShader(bandRect),
      )
      ..restore();

    // Fades the line, highlight and all, towards its end(s).
    canvas
      ..drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            colors: _alphas,
            stops: const [0, 0.3, 0.7, 1],
          ).createShader(bounds),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RulePainter oldDelegate) =>
      oldDelegate.fade != fade || oldDelegate.colors != colors;
}

/// A slide's title (e.g. コンセプト) with its underline, and its message
/// under them. Fills the slide.
class SlideHeader extends StatelessWidget {
  const SlideHeader({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 71,
          top: 14,
          height: 155,
          child: Center(child: SlideText(title, style: SlideTextStyles.title)),
        ),
        const Positioned(left: 45, top: 157, child: ShimmerRule(width: 1227)),
        Positioned(
          left: 71,
          top: 201,
          height: 155,
          child: Center(
            child: SlideText(message, style: SlideTextStyles.message),
          ),
        ),
      ],
    );
  }
}

/// A point of a slide: its round marker at [markerLeft] and [text] at
/// [textLeft], the text's middle at [centreY]. The marker is [markerDy]
/// below the text's middle (above if negative), e.g. on the first of two
/// lines. For a [Stack] filling the slide.
List<Widget> slideBullet({
  required String text,
  required double markerLeft,
  required double textLeft,
  required double centreY,
  TextStyle? style,
  double markerDy = 0,
}) {
  const box = 200.0;
  return [
    Positioned(
      left: markerLeft,
      top: centreY + markerDy - BulletMarker.size / 2,
      child: const BulletMarker(),
    ),
    Positioned(
      left: textLeft,
      top: centreY - box / 2,
      height: box,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SlideText(text, style: style ?? SlideTextStyles.bullet),
      ),
    ),
  ];
}

/// The orange-gold dot of a point, with a light rim and a soft shadow.
class BulletMarker extends StatelessWidget {
  const BulletMarker({super.key});

  static const size = 40.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SlidePalette.bullet,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xCCFFFFFF), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 4),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}

/// "2 / 6" at the bottom right. For a [Stack] filling the slide.
class PageNumber extends StatelessWidget {
  const PageNumber({super.key, required this.page, required this.of});

  final int page;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 1708,
      top: 1003,
      width: 212,
      height: 77,
      child: Center(
        child: SlideText('$page / $of', style: SlideTextStyles.pageNumber),
      ),
    );
  }
}

/// The cards of the slides: cream, with a coloured edge and a soft shadow.
BoxDecoration accentCard(
  Color edge, {
  double radius = 30,
  Color fill = SlidePalette.card,
  bool shadow = true,
}) => BoxDecoration(
  color: fill,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: edge, width: 5),
  boxShadow: shadow
      ? const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 4),
            blurRadius: 4,
            spreadRadius: 4,
          ),
        ]
      : null,
);

/// A round icon with a soft shadow under it.
class ShadowedIcon extends StatelessWidget {
  const ShadowedIcon(this.asset, {super.key, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Image.asset(asset, width: size, height: size),
    );
  }
}

/// A rounded frame with a dashed edge of [color] on [fill].
class DashedFrame extends StatelessWidget {
  const DashedFrame({super.key, required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedFramePainter(color, fill));
  }
}

class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter(this.color, this.fill);

  final Color color;
  final Color fill;

  static const _width = 5.0;
  static const _radius = 30.0;
  static const _dash = 18.0;
  static const _gap = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_width / 2),
      const Radius.circular(_radius),
    );
    canvas.drawRRect(frame, Paint()..color = fill);
    final edge = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    for (final metric in (Path()..addRRect(frame)).computeMetrics()) {
      // Whole dashes all round: stretch the gaps a little to fit.
      final count = (metric.length / (_dash + _gap)).floor();
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        canvas.drawPath(metric.extractPath(i * step, i * step + _dash), edge);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}

/// An image with a soft shadow that follows its outline.
class ShadowedImage extends StatelessWidget {
  const ShadowedImage(this.asset, {super.key});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: const Offset(0, 4),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x40000000),
                BlendMode.srcIn,
              ),
              child: Image.asset(asset, fit: BoxFit.cover),
            ),
          ),
        ),
        Image.asset(asset, fit: BoxFit.cover),
      ],
    );
  }
}
