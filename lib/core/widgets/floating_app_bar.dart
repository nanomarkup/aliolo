import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/widgets/window_controls.dart';

class AlioloAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool automaticallyImplyLeading;

  const AlioloAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor = Colors.blue,
    this.foregroundColor = Colors.white,
    this.automaticallyImplyLeading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80), // 16 top padding + 64 container
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AppBar(
                toolbarHeight: 64,
                title: DragToMoveArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: Align(alignment: Alignment.centerLeft, child: title),
                  ),
                ),
                backgroundColor: Colors.transparent,
                foregroundColor: foregroundColor,
                elevation: 0,
                automaticallyImplyLeading: automaticallyImplyLeading,
                centerTitle: false,
                titleSpacing: 20,
                actions: [
                  if (actions != null) ...actions!,
                  const WindowControls(color: Colors.white, iconSize: 24),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
