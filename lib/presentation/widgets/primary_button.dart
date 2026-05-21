import 'package:flutter/material.dart';

import 'game_ui.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      label: label,
      icon: icon ?? Icons.play_arrow_rounded,
      onPressed: onPressed,
    );
  }
}
