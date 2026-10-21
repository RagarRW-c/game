import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import 'world_atmosphere.dart';

class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child, this.worldTheme});

  final Widget child;
  final WorldVisualTheme? worldTheme;

  @override
  Widget build(BuildContext context) {
    final theme = worldTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: theme?.background ?? GameGradients.background,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: WorldAtmosphere(theme: theme)),
          if (theme != null)
            Positioned(
              right: 8,
              bottom: 40,
              child: IgnorePointer(
                child: ExcludeSemantics(
                    child: Icon(theme.decorationIcons.first,
                        color: Colors.white.withValues(alpha: 0.07),
                        size: 108)),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class GameSoftGlow extends StatelessWidget {
  const GameSoftGlow({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// A compact reward emblem shared by the smaller game dialogs.
class GameRewardEmblem extends StatelessWidget {
  const GameRewardEmblem(
      {super.key,
      required this.icon,
      this.gradient = GameGradients.badge,
      this.size = 82});

  final IconData icon;
  final Gradient gradient;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              ...GameShadows.glow(GameColors.accentGold),
              const BoxShadow(
                  color: Color(0x664A3152),
                  blurRadius: 9,
                  offset: Offset(0, 5)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
      );
}

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GameSpacing.lg),
    this.margin,
    this.gradient = GameGradients.panel,
    this.shadow,
    this.borderColor = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient gradient;
  final List<BoxShadow>? shadow;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: GameRadius.extraLargeRadius,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: shadow ??
            [
              const BoxShadow(color: Color(0x44352A57), offset: Offset(0, 5)),
              ...GameShadows.medium(const Color(0xFF28355A)),
            ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: GameRadius.extraLargeRadius,
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent],
            stops: const [0, 0.24]),
      ),
      child: child,
    );
  }
}

enum GameButtonVariant { primary, success, gold, danger, secondary }

class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GameButtonVariant.primary,
    this.height = 58,
    this.expand = true,
    this.gradient,
    this.foregroundColor,
    this.wrapLabel = false,
    this.sculpted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonVariant variant;
  final double height;
  final bool expand;
  final Gradient? gradient;
  final Color? foregroundColor;

  /// Wrap the scaled label and treat [height] as a minimum instead of fixing
  /// the height. Opt in where actions must remain fully readable in narrow UI.
  final bool wrapLabel;

  /// A raised, softly lit finish for prominent game actions. Opt-in so other
  /// screens retain their existing button presentation.
  final bool sculpted;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  Gradient get _gradient {
    if (widget.gradient != null) return widget.gradient!;
    switch (widget.variant) {
      case GameButtonVariant.success:
        return GameGradients.successButton;
      case GameButtonVariant.gold:
        return GameGradients.goldButton;
      case GameButtonVariant.danger:
        return GameGradients.dangerButton;
      case GameButtonVariant.secondary:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), GameColors.panelBlue],
        );
      case GameButtonVariant.primary:
        return GameGradients.primaryButton;
    }
  }

  Color get _foreground =>
      widget.foregroundColor ??
      (widget.variant == GameButtonVariant.secondary
          ? GameColors.primaryBlueDark
          : widget.variant == GameButtonVariant.gold
              ? const Color(0xFF573510)
              : Colors.white);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final wrapLabel =
        widget.wrapLabel || MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final radius =
        BorderRadius.circular((widget.height * 0.48).clamp(18, 28).toDouble());
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : GameDurations.quick;
    final content = AnimatedOpacity(
      duration: duration,
      opacity: enabled ? 1 : 0.72,
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1, end: _pressed ? 0.96 : 1),
          duration: duration,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            height: wrapLabel ? null : widget.height,
            constraints:
                wrapLabel ? BoxConstraints(minHeight: widget.height) : null,
            padding: wrapLabel
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                : null,
            decoration: BoxDecoration(
              gradient: enabled ? _gradient : GameGradients.disabled,
              borderRadius: radius,
              border: Border.all(
                  color: Colors.white.withValues(
                      alpha: enabled ? (widget.sculpted ? 0.65 : 0.85) : 0.4),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: Color.lerp(
                        _gradient.colors.last, const Color(0xFF172A50), 0.55)!,
                    offset: Offset(
                        0,
                        _pressed
                            ? 2
                            : widget.sculpted
                                ? 6
                                : 5)),
                BoxShadow(
                    color:
                        Colors.black.withValues(alpha: _pressed ? 0.12 : 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 7)),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              gradient: widget.sculpted
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x77FFFFFF),
                        Color(0x08FFFFFF),
                        Colors.transparent,
                        Color(0x18002320),
                      ],
                      stops: [0, 0.18, 0.65, 1],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                          Colors.white.withValues(alpha: 0.34),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.05)
                        ],
                      stops: const [
                          0,
                          0.48,
                          0.5,
                          1
                        ]),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  if (widget.sculpted)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Icon(widget.icon, color: _foreground, size: 23),
                    )
                  else
                    Icon(widget.icon, color: _foreground, shadows: const [
                      Shadow(color: Colors.black12, offset: Offset(0, 2))
                    ]),
                  const SizedBox(width: GameSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: wrapLabel ? null : 1,
                    overflow: wrapLabel
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    textAlign: wrapLabel ? TextAlign.center : null,
                    style: GameTextStyles.button.copyWith(
                      color: _foreground,
                      fontSize: widget.sculpted ? 19 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final button = widget.expand
        ? SizedBox(width: double.infinity, child: content)
        : content;
    return Semantics(button: true, enabled: enabled, child: button);
  }
}

class GameBadge extends StatelessWidget {
  const GameBadge({
    super.key,
    required this.child,
    this.icon,
    this.gradient = GameGradients.darkBadge,
  });

  final Widget child;
  final IconData? icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GameSpacing.md,
        vertical: GameSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.5),
        boxShadow: [
          const BoxShadow(color: Color(0x33202A4B), offset: Offset(0, 3)),
          ...GameShadows.light(),
        ],
      ),
      child: LayoutBuilder(
          builder: (context, constraints) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    DecoratedBox(
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0x22FFFFFF)),
                      child: Icon(icon, color: GameColors.accentGold, size: 20),
                    ),
                    const SizedBox(width: GameSpacing.sm),
                  ],
                  if (constraints.hasBoundedWidth)
                    Flexible(child: child)
                  else
                    child,
                ],
              )),
    );
  }
}

class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.worldTheme,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final WorldVisualTheme? worldTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GameSpacing.lg,
        GameSpacing.md,
        GameSpacing.lg,
        GameSpacing.sm,
      ),
      child: Row(
        children: [
          GameRoundIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            backgroundColor: worldTheme?.hudGradient.colors.first,
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines:
                  MediaQuery.textScalerOf(context).scale(1) > 1.3 ? null : 1,
              overflow: MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: GameTextStyles.title,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: GameSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class GameRoundIconButton extends StatelessWidget {
  const GameRoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.58), width: 2),
      ),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: foregroundColor, size: 28),
        ),
      ),
    );
  }
}

class GameDialogFrame extends StatelessWidget {
  const GameDialogFrame({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final compactHeader = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(
              scale: reduceMotion ? 1 : 0.94 + (value * 0.06),
              child: child,
            ),
          ),
        );
      },
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: constraints.maxHeight - 16,
              ),
              child: GameCard(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(GameSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      decoration: BoxDecoration(
                        gradient: GameGradients.dialogHeader,
                        borderRadius: GameRadius.largeRadius,
                        border: Border.all(color: Colors.white70, width: 2),
                        boxShadow:
                            GameShadows.light(GameColors.primaryBlueDark),
                      ),
                      child: compactHeader
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onClose != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GameRoundIconButton(
                                      key: const ValueKey('game_dialog_close'),
                                      icon: Icons.close_rounded,
                                      onPressed: onClose,
                                      backgroundColor: GameColors.dangerRed,
                                    ),
                                  ),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: GameTextStyles.title
                                      .copyWith(fontSize: 18),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: GameTextStyles.title
                                        .copyWith(fontSize: 25),
                                  ),
                                ),
                                if (onClose != null) ...[
                                  const SizedBox(width: 8),
                                  GameRoundIconButton(
                                    key: const ValueKey('game_dialog_close'),
                                    icon: Icons.close_rounded,
                                    onPressed: onClose,
                                    backgroundColor: GameColors.dangerRed,
                                  ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: GameSpacing.lg),
                    Flexible(
                      child: SingleChildScrollView(
                        key: const ValueKey('game_dialog_content_scroll'),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
