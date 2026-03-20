import 'dart:math';
import 'package:flutter/material.dart';

class AdditionGrid extends StatefulWidget {
  final int totalSum;
  final int maxOperand;
  final double iconSize;

  const AdditionGrid({
    super.key,
    required this.totalSum,
    required this.maxOperand,
    this.iconSize = 40,
  });

  @override
  State<AdditionGrid> createState() => _AdditionGridState();
}

class _AdditionGridState extends State<AdditionGrid> {
  late String _selectedEmoji;
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
  void didUpdateWidget(covariant AdditionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalSum != widget.totalSum) {
      _generateExercise();
    }
  }

  void _generateExercise() {
    final random = Random();
    _selectedEmoji = _emojis[random.nextInt(_emojis.length)];
    
    // Logic: A + B = totalSum where A, B <= maxOperand
    final int minA = max(0, widget.totalSum - widget.maxOperand);
    final int maxA = min(widget.totalSum, widget.maxOperand);
    
    if (maxA >= minA) {
      _part1 = random.nextInt(maxA - minA + 1) + minA;
      _part2 = widget.totalSum - _part1;
    } else {
      // Fallback
      _part1 = widget.totalSum;
      _part2 = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPart(_part1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: widget.iconSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
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
        '0',
        style: TextStyle(
          fontSize: widget.iconSize,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(
        count,
        (index) => Text(
          _selectedEmoji,
          style: TextStyle(fontSize: widget.iconSize * 0.8),
        ),
      ),
    );
  }
}
