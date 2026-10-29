import 'package:flutter/material.dart';

/// Decorative assets contain no balances, prices, notifications or controls.
class CoastalArt extends StatelessWidget {
  const CoastalArt(this.name, {super.key, this.width, this.height});
  final String name;
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/ui/coastal/$name.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
      );
}

class CoastalBackdrop extends StatelessWidget {
  const CoastalBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Positioned.fill(
            child: ExcludeSemantics(
                child: Image.asset('assets/ui/coastal/terrace.webp',
                    fit: BoxFit.cover, filterQuality: FilterQuality.medium))),
        child,
      ]);
}

enum CoastalButtonTone { blue, green, purple }

class CoastalStar extends StatelessWidget {
  const CoastalStar({super.key, required this.earned});
  final bool earned;
  @override
  Widget build(BuildContext context) => earned
      ? const CoastalArt('star', width: 74, height: 74)
      : const Icon(Icons.star_border_rounded,
          size: 64, color: Color(0xFF795925));
}

/// One semantic button and one callback; the illustrated layers are decorative.
class CoastalButton extends StatelessWidget {
  const CoastalButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.art,
      this.tone = CoastalButtonTone.blue,
      this.minHeight = 56,
      this.horizontal = false,
      this.compact = false});
  final String label;
  final VoidCallback? onPressed;
  final String? art;
  final CoastalButtonTone tone;
  final double minHeight;
  final bool horizontal;
  final bool compact;

  TextStyle _labelStyle(BuildContext context) {
    final blue = tone == CoastalButtonTone.blue;
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: compact ? 13 : 16,
        height: 1.05,
        fontWeight: FontWeight.w900,
        color: blue ? const Color(0xFF072E70) : Colors.white,
        shadows: blue
            ? null
            : const [Shadow(color: Color(0x990D4C16), offset: Offset(0, 2))]);
  }

  /// Minimum row allocation that keeps every word intact, without scaling text.
  /// Uses the same font, locale and accessibility scaler as the rendered label.
  double minimumReadableWidth(BuildContext context) {
    final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context));
    var wordWidth = 0.0;
    try {
      for (final word in label.split(RegExp(r'\s+'))) {
        painter.text = TextSpan(text: word, style: _labelStyle(context));
        painter.layout();
        if (painter.width > wordWidth) wordWidth = painter.width;
      }
    } finally {
      painter.dispose();
    }
    final iconWidth = art == null ? 0.0 : (horizontal ? 38.0 : 0.0);
    // Ink adds its 2.5px border on each side to the explicit 5px padding.
    // A subpixel guard covers paragraph rounding without scaling the label.
    return (wordWidth + iconWidth + 15.1)
        .clamp(48.0, double.infinity)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = !enabled
        ? const [Color(0xFFB9C5CA), Color(0xFF839BA8)]
        : switch (tone) {
            CoastalButtonTone.blue => const [
                Color(0xFFDDF6FF),
                Color(0xFF7ACBFA)
              ],
            CoastalButtonTone.green => const [
                Color(0xFF9DF700),
                Color(0xFF00AD21)
              ],
            CoastalButtonTone.purple => const [
                Color(0xFFDC92FF),
                Color(0xFF7526EC)
              ],
          };
    final text =
        Text(label, textAlign: TextAlign.center, style: _labelStyle(context));
    final illustration = art == null
        ? null
        : CoastalArt(art!,
            width: horizontal ? 32 : (compact ? 23 : 30),
            height: horizontal ? 32 : (compact ? 23 : 30));
    return Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        child: ExcludeSemantics(
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  enableFeedback: false,
                  borderRadius: BorderRadius.circular(20),
                  child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: Ink(
                        padding: EdgeInsets.symmetric(
                            horizontal: 5, vertical: compact ? 3 : 5),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: colors),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFFFDF0), width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x80412C1D),
                                  offset: Offset(0, 3),
                                  blurRadius: 2),
                              BoxShadow(
                                  color: Color(0x33FFFFFF),
                                  offset: Offset(0, -1),
                                  blurRadius: 1)
                            ]),
                        child: CustomPaint(
                            painter: const _ButtonBevel(),
                            child: horizontal
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        if (illustration != null) ...[
                                          illustration,
                                          const SizedBox(width: 6)
                                        ],
                                        Flexible(child: text)
                                      ])
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        if (illustration != null) illustration,
                                        text
                                      ])),
                      )),
                ))));
  }
}

class _ButtonBevel extends CustomPainter {
  const _ButtonBevel();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xBBFFFFFF));
    final shine = Path()
      ..moveTo(10, 2)
      ..quadraticBezierTo(size.width * .5, -1, size.width - 10, 2);
    canvas.drawPath(
        shine,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = const Color(0xAAFFFFFF));
  }

  @override
  bool shouldRepaint(_ButtonBevel oldDelegate) => false;
}

class CoastalPanel extends StatelessWidget {
  const CoastalPanel(
      {super.key, required this.child, this.padding = const EdgeInsets.all(8)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
      padding: padding,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFF9E9), Color(0xFFF6DEB1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFFDF1), width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x6667431E), blurRadius: 6, offset: Offset(0, 4))
          ]),
      child: child);
}

class CoastalVideoFrame extends StatelessWidget {
  const CoastalVideoFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: const Color(0x55D9F3FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66534A30), blurRadius: 8, offset: Offset(0, 4))
          ]),
      child: Padding(padding: const EdgeInsets.all(5), child: child));
}
