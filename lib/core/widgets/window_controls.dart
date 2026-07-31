import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

class WindowControls extends StatefulWidget {
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
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final isMax = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = isMax);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  void onWindowRestore() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        widget.color ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade600);
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
          if (widget.showSeparator && !widget.onlyClose)
            Container(
              height: widget.iconSize + 4,
              width: 2,
              color: effectiveColor.withValues(alpha: 0.5),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
          if (!widget.onlyClose) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Text(
                ' _',
                style: TextStyle(
                  fontSize: widget.iconSize,
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
                _isMaximized ? Icons.filter_none : Icons.crop_square,
                size:
                    widget.iconSize *
                    (_isMaximized
                        ? 0.8
                        : 1.0), // filter_none looks slightly larger
                color: effectiveColor,
              ),
              onPressed: () async {
                if (_isMaximized) {
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
            icon: Icon(
              Icons.close,
              size: widget.iconSize,
              color: effectiveColor,
            ),
            onPressed: () async {
              await windowManager.close();
            },
          ),
        ],
      ),
    );

    if (widget.padding) {
      return Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: content,
      );
    }
    return content;
  }
}
