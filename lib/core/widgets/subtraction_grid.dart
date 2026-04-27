import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aliolo/core/utils/number_localizer.dart';

class SubtractionGrid extends StatefulWidget {
  final int totalSum;
  final int maxOperand;
  final double iconSize;
  final bool useNumbers;
  final String languageCode;

  const SubtractionGrid({
    super.key,
    required this.totalSum,
    required this.maxOperand,
    this.iconSize = 40,
    this.useNumbers = false,
    this.languageCode = 'en',
  });

  @override
  State<SubtractionGrid> createState() => _SubtractionGridState();
}

class _SubtractionGridState extends State<SubtractionGrid> {
  late String _selectedSymbol;
  late int _part1;
  late int _part2;

  static const List<String> _emojis = [
    '🍎', '⭐', '🎈', '🚗', '🐶', '🐱', '🦋', '🌻', '🍦', '🎁',
    '⚽', '🚀', '🌈', '🦁', '🦉', '🍓', '🍕', '🥨', '🧸', '🔔',
    '🍉', '🐘', '🐼', '🥕', '🍩', '🍪', '🥛', '🥤', '🎨'
  ];

  @override
  void initState() {
    super.initState();
    _generateExercise();
  }

  @override
  void didUpdateWidget(covariant SubtractionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalSum != widget.totalSum ||
        oldWidget.useNumbers != widget.useNumbers) {
      _generateExercise();
    }
  }

  void _generateExercise() {
    final random = Random();
    _selectedSymbol =
        widget.useNumbers
            ? ''
            : _emojis[random.nextInt(_emojis.length)];
    
    // Logic: A - B = totalSum where A, B <= maxOperand
    // Range for A is [totalSum, maxOperand]
    final int minA = widget.totalSum;
    final int maxA = widget.maxOperand;
    
    if (maxA >= minA) {
      _part1 = random.nextInt(maxA - minA + 1) + minA;
      _part2 = _part1 - widget.totalSum;
    } else {
      // Fallback
      _part1 = widget.totalSum;
      _part2 = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPart(_part1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '-',
                  style: TextStyle(
                    fontSize: widget.iconSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              _buildPart(_part2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPart(int count) {
    if (count == 0) {
      return Text(
        NumberLocalizer.localize(0, widget.languageCode),
        style: TextStyle(
          fontSize: widget.iconSize,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
        ),
      );
    }

    if (widget.useNumbers) {
      return Text(
        NumberLocalizer.localize(count, widget.languageCode),
        style: TextStyle(
          fontSize: widget.iconSize * 1.4,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );
    }

    Widget buildWrap(int items) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.generate(
          items,
          (index) => Text(
            _selectedSymbol,
            style: TextStyle(fontSize: widget.iconSize * 0.8),
          ),
        ),
      );
    }

    if (count < 10) {
      return buildWrap(count);
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildWrap((count / 2).ceil()),
          const SizedBox(height: 4),
          buildWrap((count / 2).floor()),
        ],
      );
    }
  }
}
