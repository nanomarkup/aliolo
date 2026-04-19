import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/theme/aliolo_layout_tokens.dart';

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
              padding: AlioloLayoutTokens.pageBodyPadding,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
