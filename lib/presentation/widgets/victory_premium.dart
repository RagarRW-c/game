import 'package:flutter/material.dart';

/// Prepared derivatives of the approved standalone artwork. Dynamic values and
/// controls stay in Flutter; these images contain no rewards or action labels.
abstract final class VictoryPremiumAssets {
  static const root = 'assets/ui/victory_premium/';
  static const banner = '${root}victory_banner.png';
  static const star = '${root}victory_stars.png';
  static const unearnedStar = '${root}victory_star_unearned.png';
  static const rewards = '${root}victory_rewards_panel.png';
  static const coins = '${root}reward_coins.png';
  static const xp = '${root}reward_xp.png';
  static const primary = '${root}next_level_button.png';
  static const secondary = '${root}secondary_button.png';
  static const frame = '${root}victory_video_frame.png';
}

class PremiumVictoryBanner extends StatelessWidget {
  const PremiumVictoryBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      header: true,
      label: 'Level Complete!',
      child: AspectRatio(
          aspectRatio: 1240 / 317,
          child: Image.asset(VictoryPremiumAssets.banner,
              fit: BoxFit.contain, excludeFromSemantics: true)));
}

class PremiumVictoryStar extends StatelessWidget {
  const PremiumVictoryStar({super.key, required this.earned});
  final bool earned;

  @override
  Widget build(BuildContext context) => Image.asset(
      earned ? VictoryPremiumAssets.star : VictoryPremiumAssets.unearnedStar,
      width: 74,
      height: 74,
      fit: BoxFit.contain,
      excludeFromSemantics: true);
}

/// The frame remains in its original 9:16 coordinate system. The centered
/// 7/9 opening lies entirely inside its transparent pixels, including flowers.
/// Both video and frame keep their aspect ratio; nothing covers the subject.
class PremiumVictoryVideoFrame extends StatelessWidget {
  const PremiumVictoryVideoFrame({super.key, required this.child});
  static const openingFraction = 7 / 9;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Center(
            child: FractionallySizedBox(
                widthFactor: openingFraction,
                heightFactor: openingFraction,
                child: child)),
        Positioned.fill(
            child: IgnorePointer(
                child: Image.asset(VictoryPremiumAssets.frame,
                    fit: BoxFit.contain, excludeFromSemantics: true))),
      ]);
}

class PremiumVictoryRewards extends StatelessWidget {
  const PremiumVictoryRewards(
      {super.key,
      required this.coins,
      required this.xp,
      required this.compact,
      this.chest});
  final int coins;
  final int xp;
  final bool compact;
  final String? chest;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        // Production PNG is 1200x625. Scale its full width uniformly and only
        // stretch the blank cream center vertically. The baked Rewards title,
        // foliage and the bottom rim retain their original proportions.
        final density = 1200 / area.maxWidth;
        final coin = _IllustratedReward(
            label: 'Coins',
            value: coins,
            compact: compact,
            asset: VictoryPremiumAssets.coins);
        final experience = _IllustratedReward(
            label: 'XP',
            value: xp,
            compact: compact,
            asset: VictoryPremiumAssets.xp);
        final stackRewards = MediaQuery.textScalerOf(context).scale(1) > 1.5 ||
            coins.toString().length > 5 ||
            xp.toString().length > 5;
        return Semantics(
            container: true,
            label: 'Rewards',
            child: Stack(children: [
              Positioned.fill(
                  child: Image.asset(VictoryPremiumAssets.rewards,
                      scale: density,
                      centerSlice: Rect.fromLTRB(
                          0, 224 / density, area.maxWidth, 585 / density),
                      fit: BoxFit.fill,
                      excludeFromSemantics: true)),
              Padding(
                  padding: EdgeInsets.fromLTRB(area.maxWidth * .06,
                      224 / density + 4, area.maxWidth * .06, 14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (stackRewards)
                      Column(children: [
                        coin,
                        const SizedBox(height: 8),
                        experience
                      ])
                    else
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: coin),
                            const SizedBox(width: 12),
                            Expanded(child: experience),
                          ]),
                    if (chest != null) ...[
                      const SizedBox(height: 4),
                      Text(chest!,
                          key: const ValueKey('victory_chest'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              color: Color(0xFF653217),
                              fontWeight: FontWeight.w600)),
                    ],
                  ])),
            ]));
      });
}

class _IllustratedReward extends StatelessWidget {
  const _IllustratedReward(
      {required this.label,
      required this.value,
      required this.compact,
      required this.asset});
  final String label;
  final int value;
  final bool compact;
  final String asset;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset(asset,
            width: compact ? 36 : 48,
            height: compact ? 36 : 48,
            fit: BoxFit.contain,
            excludeFromSemantics: true),
        const SizedBox(height: 2),
        Text('+$value',
            key: ValueKey('victory_reward_$label'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: compact ? 18 : 22,
                height: 1.1,
                color: const Color(0xFF653217),
                fontWeight: FontWeight.w900)),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: compact ? 12 : 13,
                height: 1.1,
                color: const Color(0xFF653217),
                fontWeight: FontWeight.w600)),
      ]);
}

enum VictoryActionSymbol { play, replay, map }

class PremiumVictoryButton extends StatefulWidget {
  const PremiumVictoryButton(
      {super.key,
      required this.label,
      required this.symbol,
      required this.onPressed,
      this.primary = false});
  final String label;
  final VictoryActionSymbol symbol;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<PremiumVictoryButton> createState() => _PremiumVictoryButtonState();
}

class _PremiumVictoryButtonState extends State<PremiumVictoryButton> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(PremiumVictoryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        onTap: widget.onPressed,
        child: ExcludeSemantics(
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    onTap: widget.onPressed,
                    enableFeedback: false,
                    borderRadius: BorderRadius.circular(28),
                    onHighlightChanged: enabled ? _press : null,
                    child: AnimatedScale(
                        scale: _pressed ? .98 : 1,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        child: Opacity(
                            opacity: enabled ? 1 : .45,
                            child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minHeight: widget.primary ? 76 : 64),
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(child: LayoutBuilder(
                                          builder: (context, area) {
                                        // Both PNGs are 1024x276, including
                                        // their transparent curved corners.
                                        // Match the full artwork height;
                                        // stretch only the horizontal center.
                                        // The 192px end caps retain the entire
                                        // rounded rim, bevel and leaf detail.
                                        final density = 276 / area.maxHeight;
                                        return Image.asset(
                                            widget.primary
                                                ? VictoryPremiumAssets.primary
                                                : VictoryPremiumAssets
                                                    .secondary,
                                            scale: density,
                                            centerSlice: Rect.fromLTRB(
                                                192 / density,
                                                0,
                                                832 / density,
                                                276 / density),
                                            fit: BoxFit.fill,
                                            excludeFromSemantics: true);
                                      })),
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                CustomPaint(
                                                    key: const ValueKey(
                                                        'victory_action_symbol'),
                                                    size: Size.square(
                                                        widget.primary
                                                            ? 28
                                                            : 24),
                                                    painter:
                                                        _VictoryActionPainter(
                                                            widget.symbol)),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                    child: Text(widget.label,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                            fontSize:
                                                                widget.primary
                                                                    ? 20
                                                                    : 17,
                                                            height: 1.1,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            shadows: const [
                                                              Shadow(
                                                                  color: Color(
                                                                      0xCC15445B),
                                                                  offset:
                                                                      Offset(
                                                                          0, 1),
                                                                  blurRadius: 2)
                                                            ]))),
                                              ])),
                                    ]))))))));
  }
}

/// Original simple action symbols, not assets or glyphs from the reference game.
class _VictoryActionPainter extends CustomPainter {
  const _VictoryActionPainter(this.symbol);
  final VictoryActionSymbol symbol;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (symbol) {
      case VictoryActionSymbol.play:
        canvas.drawPath(
            Path()
              ..moveTo(5, 2)
              ..lineTo(18, 10)
              ..lineTo(5, 18)
              ..close(),
            paint);
      case VictoryActionSymbol.replay:
        paint.style = PaintingStyle.stroke;
        canvas.drawArc(
            const Rect.fromLTWH(4, 4, 13, 13), -2.2, 5.2, false, paint);
        canvas.drawPath(
            Path()
              ..moveTo(3, 1)
              ..lineTo(3, 7)
              ..lineTo(9, 7),
            paint);
      case VictoryActionSymbol.map:
        paint.style = PaintingStyle.stroke;
        canvas.drawPath(
            Path()
              ..moveTo(2, 4)
              ..lineTo(7, 2)
              ..lineTo(13, 5)
              ..lineTo(18, 3)
              ..lineTo(18, 16)
              ..lineTo(13, 18)
              ..lineTo(7, 15)
              ..lineTo(2, 17)
              ..close()
              ..moveTo(7, 2)
              ..lineTo(7, 15)
              ..moveTo(13, 5)
              ..lineTo(13, 18),
            paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VictoryActionPainter oldDelegate) =>
      oldDelegate.symbol != symbol;
}
