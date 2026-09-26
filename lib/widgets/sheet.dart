
import 'dart:ui';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';
import 'text.dart';
import 'pop_scope.dart';

@immutable
class SheetProps {
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool blur;
  final Color? barrierColor;

  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = false,
    this.barrierColor,
  });
}

@immutable
class ExtendProps {
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
  final bool forceFull;

  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = false,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: props.isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) {
        return builder(context, SheetType.bottomSheet);
      },
      showDragHandle: false,
      useSafeArea: props.useSafeArea,
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      isScrollControlled: props.isScrollControlled,
      barrierColor: props.barrierColor,
      backgroundColor: Colors.transparent,
      elevation: 0,
      context: context,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (_) {
        return builder(context, SheetType.sideSheet);
      },
    ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required SheetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile || props.forceFull) {
    true => BaseNavigator.push(context, builder(context, SheetType.page)),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      backgroundColor: Colors.transparent,
      elevation: 0,
      context: context,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (context) {
        return builder(context, SheetType.sideSheet);
      },
    ),
  };
}

class AdaptiveSheetScaffold extends StatelessWidget {
  final SheetType type;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool? showScrollGradient;

  const AdaptiveSheetScaffold({
    super.key,
    required this.type,
    required this.body,
    required this.title,
    this.actions = const [],
    this.leading,
    this.showScrollGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.colorScheme.brightness == Brightness.light;
    final frostedColor = (isLight
            ? context.colorScheme.surface
            : context.colorScheme.surfaceContainer)
        .withValues(alpha: isLight ? 0.94 : 0.88);
    final borderColor = isLight
        ? context.colorScheme.outlineVariant.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.14);
    final backgroundColor = context.colorScheme.surface;
    final bottomSheet = type == SheetType.bottomSheet;
    final sideSheet = type == SheetType.sideSheet;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final implyLeading = !bottomSheet && (!(actions.isEmpty && sideSheet));
    final hasLeading = leading != null || (implyLeading && canPop);
    final appBar = AppBar(
      leading: leading != null
          ? Padding(
              padding: const EdgeInsets.only(left: 2.0),
              child: leading,
            )
          : null,
      leadingWidth: hasLeading ? 58.0 : null,
      forceMaterialTransparency: (bottomSheet || sideSheet) ? true : false,
      automaticallyImplyLeading: implyLeading,
      titleSpacing: hasLeading ? 0.0 : (bottomSheet ? null : 18.0),
      centerTitle: bottomSheet,
      backgroundColor: (bottomSheet || sideSheet)
          ? Colors.transparent
          : backgroundColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.0,
      title: EmojiText(
        title,
      ),
      actions: genActions([
        if (actions.isEmpty && sideSheet) const CloseButton(),
        ...actions,
      ]),
    );
    final content = bottomSheet
        ? ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(35.0),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: frostedColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(35.0),
                  ),
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                    left: BorderSide(color: borderColor, width: 1),
                    right: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            alignment: Alignment.center,
                            height: 4,
                            width: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        appBar,
                        Flexible(
                          flex: 1,
                          child: body,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : sideSheet
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: frostedColor,
                      border: Border(
                        left: BorderSide(color: borderColor, width: 1),
                      ),
                    ),
                    child: CommonScaffold(
                      appBar: appBar,
                      backgroundColor: Colors.transparent,
                      surfaceColor: frostedColor,
                      body: body,
                      showScrollGradient: false,
                    ),
                  ),
                ),
              )
            : CommonScaffold(
                appBar: appBar,
                backgroundColor: backgroundColor,
                body: body,
                showScrollGradient: showScrollGradient,
              );

    final isTv = globalState.isAndroidTV;
    return PopScope(
      canPop: !isTv,
      onPopInvokedWithResult: !isTv
          ? null
          : (didPop, result) {
              if (didPop) return;
              if (dismissTvInputFocus()) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.of(context).pop();
            },
      child: content,
    );
  }
}
