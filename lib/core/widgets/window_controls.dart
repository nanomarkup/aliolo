import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

class WindowControls extends StatelessWidget {
  final bool onlyClose;
  final bool showSeparator;
  final Color? color;
  final bool padding;
  final double iconSize;

  const WindowControls({
    super.key,
    this.onlyClose = false,
    this.showSeparator = true,
    this.color,
    this.padding = true,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        color ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade600);
    final effectiveColor = defaultColor;

    final content = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) {
        windowManager.startDragging();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showSeparator && !onlyClose)
            Container(
              height: iconSize + 4,
              width: 2,
              color: effectiveColor.withOpacity(0.5),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
          if (!onlyClose) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Text(
                ' _',
                style: TextStyle(
                  fontSize: iconSize,
                  fontWeight: FontWeight.bold,
                  color: effectiveColor,
                ),
              ),
              onPressed: () async {
                await windowManager.minimize();
              },
            ),
            const SizedBox(width: 12),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.crop_square,
                size: iconSize,
                color: effectiveColor,
              ),
              onPressed: () async {
                bool isMaximized = await windowManager.isMaximized();
                if (isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.close, size: iconSize, color: effectiveColor),
            onPressed: () async {
              await windowManager.close();
            },
          ),
        ],
      ),
    );

    if (padding) {
      return Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: content,
      );
    }
    return content;
  }
}
