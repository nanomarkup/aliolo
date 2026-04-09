import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';

class AlioloPage extends StatelessWidget {
  final Widget title;
  final List<Widget>? actions;
  final List<Widget>? overflowActions;
  final Widget body;
  final Color? appBarColor;
  final double maxWidth;

  const AlioloPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.overflowActions,
    this.appBarColor,
    this.maxWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    const double standardTopGap = 92.0;

    return ResizeWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AlioloAppBar(
          title: title,
          actions: actions,
          overflowActions: overflowActions,
          backgroundColor: appBarColor ?? Theme.of(context).primaryColor,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, standardTopGap, 16, 32),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
