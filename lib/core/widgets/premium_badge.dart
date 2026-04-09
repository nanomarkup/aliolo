import 'package:flutter/material.dart';

class PremiumBadge extends StatelessWidget {
  final double size;
  final Color? color;

  const PremiumBadge({
    super.key,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: (color ?? Colors.amber).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.workspace_premium,
        size: size,
        color: color ?? Colors.amber,
      ),
    );
  }
}
