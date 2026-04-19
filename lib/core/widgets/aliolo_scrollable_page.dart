import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/theme/aliolo_layout_tokens.dart';

class AlioloScrollablePage extends StatelessWidget {
  final Widget title;
  final List<Widget>? actions;
  final List<Widget>? overflowActions;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? slivers;
  final Widget? body;
  final Widget? fixedBody;
  final Color? appBarColor;
  final double maxWidth;
  final double appBarMaxWidth;
  final ScrollController? controller;
  final Widget? floatingActionButton;
  final Alignment titleAlignment;

  const AlioloScrollablePage({
    super.key,
    required this.title,
    this.actions,
    this.overflowActions,
    this.leading,
    this.leadingWidth,
    this.slivers,
    this.body,
    this.fixedBody,
    this.appBarColor,
    this.maxWidth = 640,
    this.appBarMaxWidth = 700,
    this.controller,
    this.floatingActionButton,
    this.titleAlignment = Alignment.centerLeft,
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
          leading: leading,
          leadingWidth: leadingWidth,
          titleAlignment: titleAlignment,
          backgroundColor: appBarColor ?? Theme.of(context).primaryColor,
          maxWidth: appBarMaxWidth,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  Column(
                children: [
                      const SizedBox(height: AlioloLayoutTokens.bodyTopGap),
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
                  if (floatingActionButton != null)
                    Positioned(
                      bottom: 16,
                      right: 0,
                      child: floatingActionButton!,
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
