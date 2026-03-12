import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';

class AlioloScrollablePage extends StatelessWidget {
  final Widget title;
  final List<Widget>? actions;
  final List<Widget>? slivers;
  final Widget? body;
  final Color? appBarColor;
  final double maxWidth;
  final ScrollController? controller;

  const AlioloScrollablePage({
    super.key,
    required this.title,
    this.actions,
    this.slivers,
    this.body,
    this.appBarColor,
    this.maxWidth = 640,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    const double standardTopGap = 100.0;

    return ResizeWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AlioloAppBar(
          title: title,
          actions: actions,
          backgroundColor: appBarColor ?? Theme.of(context).primaryColor,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomScrollView(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverPadding(
                    padding: EdgeInsets.only(top: standardTopGap),
                  ),
                  if (body != null) SliverToBoxAdapter(child: body!),
                  if (slivers != null) ...slivers!,
                  const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
