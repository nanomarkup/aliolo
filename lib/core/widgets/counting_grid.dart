import 'dart:math';
import 'package:flutter/material.dart';

class CountingGrid extends StatefulWidget {
  final int count;
  final Color? color;
  final double iconSize;

  const CountingGrid({
    super.key,
    required this.count,
    this.color,
    this.iconSize = 40,
  });

  @override
  State<CountingGrid> createState() => _CountingGridState();
}

class _CountingGridState extends State<CountingGrid> {
  late String _selectedEmoji;

  static const List<String> _emojis = [
    '🍎', '⭐', '🎈', '🚗', '🐶', '🐱', '🦋', '🌻', '🍦', '🎁',
    '⚽', '🚀', '🌈', '🦁', '🦉', '🍓', '🍕', '🥨', '🧸', '🔔',
    '🍉', '🐘', '🐼', '🥕', '🍩', '🍪', '🥛', '🥤', '🎨'
  ];

  @override
  void initState() {
    super.initState();
    _pickRandomEmoji();
  }

  @override
  void didUpdateWidget(covariant CountingGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _pickRandomEmoji();
    }
  }

  void _pickRandomEmoji() {
    _selectedEmoji = _emojis[Random().nextInt(_emojis.length)];
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic adjustments based on count to optimize space
    final double spacing = widget.count > 10 ? 8.0 : 12.0;
    final double padding = widget.count > 10 ? 8.0 : 16.0;
    
    // Slightly reduce icon size if count is very high to avoid overflow
    double effectiveIconSize = widget.iconSize;
    if (widget.count > 15 && widget.iconSize > 30) {
      effectiveIconSize = widget.iconSize * 0.85;
    }

    Widget buildRow(int items) {
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.generate(
          items,
          (index) => Text(
            _selectedEmoji,
            style: TextStyle(fontSize: effectiveIconSize),
          ),
        ),
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: widget.count < 10 
            ? buildRow(widget.count)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildRow((widget.count / 2).ceil()),
                  const SizedBox(height: 8),
                  buildRow((widget.count / 2).floor()),
                ],
              ),
        ),
      ),
    );
  }
}
