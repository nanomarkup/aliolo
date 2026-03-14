import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';

class AlioloScrollablePage extends StatelessWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? slivers;
  final Widget? body;
  final Widget? fixedBody;
  final Color? appBarColor;
  final double maxWidth;
  final ScrollController? controller;
  final Widget? floatingActionButton;
  final Alignment titleAlignment;

  const AlioloScrollablePage({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.leadingWidth,
    this.slivers,
    this.body,
    this.fixedBody,
    this.appBarColor,
    this.maxWidth = 640,
    this.controller,
    this.floatingActionButton,
    this.titleAlignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    const double standardTopGap = 92.0;

    return ResizeWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        floatingActionButton: floatingActionButton,
        appBar: AlioloAppBar(
          title: title,
          actions: actions,
          leading: leading,
          leadingWidth: leadingWidth,
          titleAlignment: titleAlignment,
          backgroundColor: appBarColor ?? Theme.of(context).primaryColor,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: standardTopGap),
                  if (fixedBody != null) fixedBody!,
                  Expanded(
                    child: CustomScrollView(
                      controller: controller,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (body != null) SliverToBoxAdapter(child: body!),
                        if (slivers != null) ...slivers!,
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 48),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
