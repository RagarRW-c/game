import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/world_theme.dart';

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
          Positioned(
            left: -42,
            top: 118,
            width: 180,
            height: 180,
            child: GameSoftGlow(
              color: theme?.primaryAccent ?? GameColors.primaryBlueLight,
            ),
          ),
          Positioned(
            right: -54,
            top: 242,
            width: 210,
            height: 210,
            child: GameSoftGlow(
              color: theme?.secondaryAccent ?? GameColors.secondaryPurple,
            ),
          ),
          Positioned(
            left: GameSpacing.xxl,
            right: GameSpacing.xxl,
            bottom: 96,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: GameRadius.extraLargeRadius,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          ...List<Widget>.generate(18, (index) {
            final left = (index * 47 % 360).toDouble();
            final top = 28 + (index * 83 % 660).toDouble();
            final size = 2.5 + (index % 3);
            final icon = theme == null
                ? null
                : theme.decorationIcons[index % theme.decorationIcons.length];
            return Positioned(
              left: left,
              top: top,
              width: icon == null ? size : 16,
              height: icon == null ? size : 16,
              child: icon == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.56),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    )
                  : Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.22),
                      size: 16,
                    ),
            );
          }),
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
        boxShadow: shadow ?? GameShadows.heavy(),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonVariant variant;
  final double height;
  final bool expand;

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

  Color get _foreground => widget.variant == GameButtonVariant.secondary
      ? GameColors.primaryBlueDark
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final content = AnimatedOpacity(
      duration: GameDurations.quick,
      opacity: enabled ? 1 : 0.48,
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1, end: _pressed ? 0.96 : 1),
          duration: GameDurations.quick,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: enabled ? _gradient : GameGradients.disabled,
              borderRadius: GameRadius.largeRadius,
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: GameShadows.medium(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: _foreground),
                  const SizedBox(width: GameSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTextStyles.button.copyWith(color: _foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: content)
        : content;
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
        borderRadius: GameRadius.largeRadius,
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: GameShadows.medium(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: GameColors.accentGold, size: 20),
            const SizedBox(width: GameSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }
}

class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

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
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        borderRadius: GameRadius.mediumRadius,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.58), width: 2),
      ),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      child: InkWell(
        onTap: onPressed,
        borderRadius: GameRadius.mediumRadius,
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(scale: 0.9 + (value * 0.1), child: child),
          ),
        );
      },
      child: Container(
        color: GameColors.dialogOverlay.withValues(alpha: 0.62),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GameCard(
                  margin: const EdgeInsets.all(GameSpacing.xl),
                  padding: const EdgeInsets.fromLTRB(
                    GameSpacing.xl,
                    72,
                    GameSpacing.xl,
                    GameSpacing.xl,
                  ),
                  child: child,
                ),
                Positioned(
                  left: GameSpacing.xxl,
                  right: GameSpacing.xxl,
                  top: 0,
                  child: Container(
                    height: 82,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: GameGradients.dialogHeader,
                      borderRadius: GameRadius.extraLargeRadius,
                      border: Border.all(color: Colors.white70, width: 3),
                      boxShadow: GameShadows.medium(GameColors.primaryBlueDark),
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GameTextStyles.title.copyWith(fontSize: 30),
                    ),
                  ),
                ),
                if (onClose != null)
                  Positioned(
                    right: GameSpacing.lg,
                    top: 48,
                    child: GameRoundIconButton(
                      icon: Icons.close_rounded,
                      onPressed: onClose,
                      backgroundColor: GameColors.dangerRed,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
