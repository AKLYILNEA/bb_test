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
    this.blur = true,
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
    this.blur = true,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

class _BlurModalBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  final ImageFilter? _filter;

  _BlurModalBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle,
    required super.isScrollControlled,
    super.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = false,
    super.sheetAnimationStyle,
    ImageFilter? filter,
  }) : _filter = filter;

  @override
  ImageFilter? get filter => _filter;
}

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => () {
        final navigator = Navigator.of(context);
        final localizations = MaterialLocalizations.of(context);
        return navigator.push<T>(
          _BlurModalBottomSheetRoute<T>(
            builder: (_) => builder(context, SheetType.bottomSheet),
            capturedThemes:
                InheritedTheme.capture(from: context, to: navigator.context),
            isScrollControlled: props.isScrollControlled,
            barrierLabel: localizations.scrimLabel,
            barrierOnTapHint:
                localizations.scrimOnTapHint(localizations.bottomSheetLabel),
            backgroundColor: Colors.transparent,
            elevation: 0,
            modalBarrierColor: props.barrierColor ??
                Theme.of(context).bottomSheetTheme.modalBarrierColor,
            showDragHandle: false,
            useSafeArea: props.useSafeArea,
            filter: props.blur ? commonFilter : null,
          ),
        );
      }(),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        isScrollControlled: props.isScrollControlled,
        barrierColor: props.barrierColor,
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
      forceMaterialTransparency: bottomSheet ? true : false,
      automaticallyImplyLeading: implyLeading,
      titleSpacing: hasLeading ? 0.0 : (bottomSheet ? null : 18.0),
      centerTitle: bottomSheet,
      backgroundColor: backgroundColor,
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
        ? Material(
            color: backgroundColor,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(35.0),
              ),
            ),
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
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  appBar,
                  Flexible(
                    flex: 1,
                    child: (showScrollGradient ?? true)
                        ? ScrollFeatherGradientOverlay(
                            surfaceColor: backgroundColor,
                            child: body,
                          )
                        : body,
                  ),
                ],
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
