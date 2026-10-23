import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/daily_wheel_reward.dart';

/// All artwork and the reveal outline use this same, unscaled wheel space.
abstract final class LuckyWheelGeometry {
  static const size = 280.0;
  static const center = Offset(size / 2, size / 2);
  static const sectorRadius = 112.0;
  static const hubRadius = 32.0;
  static const count = 9;
  static const sweep = 2 * math.pi / count;

  static double centerAngle(int index) => -math.pi / 2 + index * sweep;

  static Path sectorPath(int index) {
    RangeError.checkValueInInterval(index, 0, count - 1, 'index');
    final start = centerAngle(index) - sweep / 2;
    final outer = Rect.fromCircle(center: center, radius: sectorRadius);
    final inner = Rect.fromCircle(center: center, radius: hubRadius);
    return Path()
      ..arcTo(outer, start, sweep, true)
      ..arcTo(inner, start + sweep, -sweep, false)
      ..close();
  }

  static Offset rewardCenter(int index) =>
      center +
      Offset(math.cos(centerAngle(index)), math.sin(centerAngle(index))) * 77;
}

/// A single retained illustration: nine enamel wedges and one dimensional rim.
class LuckyWheelFace extends StatelessWidget {
  const LuckyWheelFace({
    super.key,
    required this.rewards,
    required this.artKey,
    required this.segmentKeys,
  });

  final List<DailyWheelReward> rewards;
  final GlobalKey artKey;
  final List<GlobalKey> segmentKeys;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: LuckyWheelGeometry.size,
        height: LuckyWheelGeometry.size,
        child: CustomPaint(
          key: artKey,
          painter: const _WheelFacePainter(),
          child: Stack(children: [
            for (var index = 0; index < rewards.length; index++)
              Positioned(
                left: LuckyWheelGeometry.rewardCenter(index).dx - 26,
                top: LuckyWheelGeometry.rewardCenter(index).dy - 27,
                child: Transform.rotate(
                  angle: index * LuckyWheelGeometry.sweep,
                  child: SizedBox(
                    key: segmentKeys[index],
                    width: 52,
                    height: 54,
                    child: Semantics(
                      label: rewards[index].label,
                      child: ExcludeSemantics(
                        child: MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(textScaler: TextScaler.noScaling),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (rewards[index].coins != null)
                                const _CoinStack()
                              else
                                Icon(rewards[index].icon,
                                    color: const Color(0xFF7351BE),
                                    size: 26,
                                    shadows: const [
                                      Shadow(
                                          color: Colors.white, blurRadius: 2),
                                    ]),
                              Text(
                                rewards[index].shortLabel,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF68401C),
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 3),
                                    Shadow(color: Colors.white, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

extension LuckyWheelRewardVisuals on DailyWheelReward {
  String get label =>
      coins != null ? '+$coins coins' : '+1 $shortLabel booster';
  String get shortLabel => switch (this) {
        DailyWheelReward.hint => 'Hint',
        DailyWheelReward.shuffle => 'Shuffle',
        DailyWheelReward.undo => 'Undo',
        _ => '$coins',
      };
  IconData get icon => switch (this) {
        DailyWheelReward.hint => Icons.pets_rounded,
        DailyWheelReward.shuffle => Icons.air_rounded,
        DailyWheelReward.undo => Icons.arrow_back_rounded,
        _ => Icons.monetization_on_rounded,
      };
}

class _CoinStack extends StatelessWidget {
  const _CoinStack();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 38,
        height: 31,
        child: CustomPaint(painter: _CoinStackPainter()),
      );
}

class _CoinStackPainter extends CustomPainter {
  const _CoinStackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = Paint()..color = const Color(0xFFDB820B);
    final top = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF5A5), Color(0xFFFFC128), Color(0xFFF29910)],
      ).createShader(const Rect.fromLTWH(0, 0, 38, 31));
    for (final coin in [
      const Offset(11, 20),
      const Offset(11, 15),
      const Offset(11, 10),
      const Offset(25, 22),
      const Offset(25, 17),
    ]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: coin + const Offset(0, 3), width: 19, height: 10),
          side);
      canvas.drawOval(
          Rect.fromCenter(center: coin, width: 19, height: 10), top);
      canvas.drawOval(
          Rect.fromCenter(center: coin, width: 14, height: 6),
          Paint()
            ..color = const Color(0xFFEFAD1E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinStackPainter oldDelegate) => false;
}

class _WheelFacePainter extends CustomPainter {
  const _WheelFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const c = LuckyWheelGeometry.center;
    final p = Paint();
    final shadow = Path()..addOval(Rect.fromCircle(center: c, radius: 132));
    canvas.drawShadow(shadow, const Color(0xFF57300F), 12, true);
    canvas.drawCircle(c, 133, p..color = const Color(0xFF985012));
    canvas.drawCircle(
        c,
        130,
        p
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEE99), Color(0xFFFFAE2D), Color(0xFFB95D0F)],
          ).createShader(const Rect.fromLTWH(7, 7, 266, 266)));
    canvas.drawCircle(
        c,
        119,
        p
          ..color = const Color(0xFFB15B17)
          ..shader = null);
    for (var index = 0; index < LuckyWheelGeometry.count; index++) {
      final wedge = LuckyWheelGeometry.sectorPath(index);
      canvas.drawPath(
          wedge,
          p
            ..shader = RadialGradient(
              center: const Alignment(-.25, -.35),
              radius: 1.1,
              colors: index.isEven
                  ? const [Color(0xFFFFFFFF), Color(0xFFFFF2D9)]
                  : const [Color(0xFFF2DDFF), Color(0xFFCBA0FA)],
            ).createShader(const Rect.fromLTWH(28, 28, 224, 224)));
      canvas.drawPath(
          wedge,
          p
            ..shader = null
            ..color = const Color(0xFFFFDB9C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      p.style = PaintingStyle.fill;
    }
    canvas.drawCircle(
        c,
        119,
        p
          ..color = const Color(0x66FFF8D4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawCircle(
        c,
        125,
        p
          ..color = const Color(0xFFFFD76B)
          ..strokeWidth = 3);
    p.style = PaintingStyle.fill;
    for (var index = 0; index < 9; index++) {
      final a = -math.pi / 2 + index * 2 * math.pi / 9;
      final bolt = c + Offset(math.cos(a), math.sin(a)) * 125;
      canvas.drawCircle(
          bolt + const Offset(0, 1.5), 4.2, p..color = const Color(0xFF9D5B17));
      canvas.drawCircle(bolt, 3.7, p..color = const Color(0xFFFFF1B2));
      canvas.drawCircle(
          bolt + const Offset(-1, -1), 1.1, p..color = Colors.white);
    }
    canvas.drawCircle(
        c + const Offset(0, 3), 35, p..color = const Color(0xFF9F4C28));
    canvas.drawCircle(
        c,
        33,
        p
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4B8), Color(0xFFFFB939), Color(0xFFD66A27)],
          ).createShader(Rect.fromCircle(center: c, radius: 33)));
    canvas.drawCircle(
        c,
        27,
        p
          ..color = const Color(0xFFF8DE9B)
          ..shader = null);
    canvas.drawCircle(c, 22, p..color = const Color(0xFFFFEBD0));
    canvas.drawCircle(
        c + const Offset(-6, -7), 7, p..color = const Color(0xAAFFFFFF));
  }

  @override
  bool shouldRepaint(covariant _WheelFacePainter oldDelegate) => false;
}

/// Stationary title, pointer and stand; no ticker or cached image resources.
class LuckyWheelRibbon extends StatelessWidget {
  const LuckyWheelRibbon({super.key});

  static const _title = 'Codzienny prezent';
  static const _horizontalInset = 30.0;
  static const _titleStyle = TextStyle(
    color: Color(0xFFFFF8E7),
    fontSize: 22,
    fontWeight: FontWeight.w900,
    shadows: [
      Shadow(color: Color(0xFF935009), offset: Offset(0, 2), blurRadius: 3)
    ],
  );

  /// The exact filled panel, shared with geometry assertions for scaled text.
  static Path bandPath(Size size) => Path()
    ..moveTo(24, 15)
    ..quadraticBezierTo(size.width / 2, -3, size.width - 24, 15)
    ..lineTo(size.width - 24, size.height - 10)
    ..quadraticBezierTo(size.width / 2, size.height - 18, 24, size.height - 10)
    ..close();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final paragraph = TextPainter(
            text: TextSpan(
                text: _title,
                style: DefaultTextStyle.of(context).style.merge(_titleStyle)),
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth - 2 * _horizontalInset);
          // The painter and paragraph now share the same width. Reserve room
          // around every wrapped line instead of estimating from text scale.
          final height = math.max(72.0, paragraph.height + 44);
          paragraph.dispose();
          return SizedBox(
            height: height,
            width: double.infinity,
            child: const CustomPaint(
              painter: _RibbonPainter(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: _horizontalInset, vertical: 20),
                child: Center(
                  child: Text(_title,
                      textAlign: TextAlign.center, style: _titleStyle),
                ),
              ),
            ),
          );
        },
      );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final middle = h / 2;
    final p = Paint()..color = const Color(0xFFB35D0A);
    final left = Path()
      ..moveTo(20, 22)
      ..lineTo(4, 17)
      ..lineTo(15, middle)
      ..lineTo(5, h - 15)
      ..lineTo(40, h - 22)
      ..close();
    final right = Path()
      ..moveTo(w - 20, 22)
      ..lineTo(w - 4, 17)
      ..lineTo(w - 15, middle)
      ..lineTo(w - 5, h - 15)
      ..lineTo(w - 40, h - 22)
      ..close();
    canvas.drawPath(left, p);
    canvas.drawPath(right, p);
    final ribbon = LuckyWheelRibbon.bandPath(size);
    canvas.drawShadow(ribbon, const Color(0xFF76400C), 5, true);
    canvas.drawPath(
        ribbon,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFDA64), Color(0xFFFFAD1E), Color(0xFFE8810D)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        ribbon,
        Paint()
          ..color = const Color(0xFFFFE990)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => false;
}

class LuckyWheelPointer extends StatelessWidget {
  const LuckyWheelPointer({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 48,
        height: 62,
        child: CustomPaint(painter: _PointerPainter()),
      );
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(24, 60)
      ..cubicTo(16, 48, 5, 29, 7, 19)
      ..cubicTo(9, 2, 39, 2, 41, 19)
      ..cubicTo(43, 29, 32, 48, 24, 60)
      ..close();
    canvas.drawShadow(path, const Color(0xFF59222D), 6, true);
    canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9795), Color(0xFFFF3E59), Color(0xFFD41942)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFAE1743)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(
        const Offset(24, 23), 10, Paint()..color = const Color(0xFFFFD044));
    canvas.drawCircle(
        const Offset(21, 20), 3, Paint()..color = const Color(0xAAFFFFFF));
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}

class LuckyWheelPedestal extends StatelessWidget {
  const LuckyWheelPedestal({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 280,
        height: 78,
        child: CustomPaint(painter: _PedestalPainter()),
      );
}

class _PedestalPainter extends CustomPainter {
  const _PedestalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final support = Path()
      ..moveTo(100, 0)
      ..lineTo(180, 0)
      ..lineTo(193, 33)
      ..lineTo(87, 33)
      ..close();
    canvas.drawPath(support, p..color = const Color(0xFF9E562C));
    final base = RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 25, 244, 42), const Radius.circular(17));
    canvas.drawShadow(Path()..addRRect(base), const Color(0xFF40271C), 8, true);
    canvas.drawRRect(
        base,
        p
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7B675), Color(0xFFC97C47), Color(0xFF994C2A)],
          ).createShader(const Rect.fromLTWH(18, 25, 244, 42)));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(30, 29, 220, 5), const Radius.circular(3)),
        p
          ..shader = null
          ..color = const Color(0x88FFE1AD));
    final grass = Path()
      ..moveTo(0, 56)
      ..quadraticBezierTo(12, 43, 26, 50)
      ..quadraticBezierTo(41, 34, 55, 47)
      ..quadraticBezierTo(73, 37, 91, 49)
      ..quadraticBezierTo(112, 38, 130, 48)
      ..quadraticBezierTo(153, 37, 173, 49)
      ..quadraticBezierTo(197, 35, 216, 47)
      ..quadraticBezierTo(239, 39, 254, 50)
      ..quadraticBezierTo(272, 43, 280, 57)
      ..lineTo(280, 73)
      ..quadraticBezierTo(143, 83, 0, 73)
      ..close();
    canvas.drawShadow(grass, const Color(0xFF2A6E20), 3, true);
    canvas.drawPath(
        grass,
        p
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB4EE5C), Color(0xFF73C736)],
          ).createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(covariant _PedestalPainter oldDelegate) => false;
}
