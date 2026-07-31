import 'package:flutter/material.dart';

class ResizeWrapper extends StatelessWidget {
  final Widget child;
  final bool resizable;

  const ResizeWrapper({super.key, required this.child, this.resizable = true});

  @override
  Widget build(BuildContext context) {
    // Simplified to avoid rendering issues on some Linux systems
    return child;
  }
}
