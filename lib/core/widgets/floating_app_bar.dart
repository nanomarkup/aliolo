import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/theme/aliolo_layout_tokens.dart';

class AlioloAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final List<Widget>? overflowActions;
  final Widget? leading;
  final double? leadingWidth;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool automaticallyImplyLeading;
  final Alignment titleAlignment;
  final double maxWidth;

  const AlioloAppBar({
    super.key,
    required this.title,
    this.actions,
    this.overflowActions,
    this.leading,
    this.leadingWidth,
    this.backgroundColor = Colors.blue,
    this.foregroundColor = Colors.white,
    this.automaticallyImplyLeading = false,
    this.titleAlignment = Alignment.centerLeft,
    this.maxWidth = 700,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AlioloLayoutTokens.appBarContentHeight),
      child: Align(
        alignment: titleAlignment,
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: AlioloLayoutTokens.appBarTitleSize,
            fontWeight: FontWeight.bold,
            color: foregroundColor,
            overflow: TextOverflow.ellipsis,
          ),
          maxLines: 1,
          softWrap: false,
          child: title,
        ),
      ),
    );

    return PreferredSize(
      preferredSize: const Size.fromHeight(AlioloLayoutTokens.appBarPreferredHeight),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AlioloLayoutTokens.appBarOuterTopPadding,
              AlioloLayoutTokens.appBarOuterTopPadding,
              AlioloLayoutTokens.appBarOuterTopPadding,
              0,
            ),
            child: Container(
              height: AlioloLayoutTokens.appBarContentHeight,
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
                toolbarHeight: AlioloLayoutTokens.appBarContentHeight,
                title: kIsWeb ? titleWidget : DragToMoveArea(child: titleWidget),
                backgroundColor: Colors.transparent,
                foregroundColor: foregroundColor,
                elevation: 0,
                leading: leading,
                leadingWidth: leadingWidth,
                automaticallyImplyLeading: automaticallyImplyLeading,
                centerTitle: false,
                titleSpacing: leading != null ? 0 : 20,
                actions: [
                  if (actions != null) ...actions!,
                  if (overflowActions != null && overflowActions!.isNotEmpty)
                    PopupMenuButton<int>(
                      icon: Icon(Icons.more_vert, color: foregroundColor),
                      onSelected: (index) {
                        final action = overflowActions![index];
                        if (action is IconButton) {
                          action.onPressed?.call();
                        }
                      },
                      itemBuilder: (context) => overflowActions!
                          .asMap()
                          .entries
                          .map((e) => PopupMenuItem<int>(
                                value: e.key,
                                child: e.value is IconButton
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconTheme(
                                            data: IconThemeData(
                                              color: backgroundColor,
                                            ),
                                            child: (e.value as IconButton).icon,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            (e.value as IconButton).tooltip ?? 'Action',
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                        ],
                                      )
                                    : e.value,
                              ))
                          .toList(),
                    ),
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
  Size get preferredSize =>
      const Size.fromHeight(AlioloLayoutTokens.appBarPreferredHeight);
}
