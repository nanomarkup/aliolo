import 'package:flutter/material.dart';

class NumberGrid extends StatelessWidget {
  final String displayChar;
  final double fontSize;
  final Color? color;

  const NumberGrid({
    super.key,
    required this.displayChar,
    this.fontSize = 200,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            displayChar,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
