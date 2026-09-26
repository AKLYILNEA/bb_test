import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/app.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BaseNavigator {
  static Future<T?> push<T>(
    BuildContext context,
    Widget child, {
    bool maintainState = true,
  }) async {
    if (globalState.appState.viewMode != ViewMode.mobile) {
      return await Navigator.of(
        context,
      ).push<T>(
        CommonDesktopRoute(
          builder: (context) => child,
          maintainState: maintainState,
        ),
      );
    }
    return await Navigator.of(
      context,
    ).push<T>(
      _CleanCupertinoPageRoute(
        builder: (context) => child,
        maintainState: maintainState,
      ),
    );
  }
}

class _CleanCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _CleanCupertinoPageRoute({
    required super.builder,
    super.title,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
  }) : super(allowSnapshotting: false);

  @override
  Color? get barrierColor => null;

  // 新界面滑入时把下层旧界面压暗（旧界面位移幅度天生比新界面小，压暗后两侧节奏看起来同步），
  // 新界面左上 / 左下用超椭圆包边，圆角取手机屏幕圆角量级，落定后与屏幕圆角基本重合
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(
                alpha: _pushedPageScrimOpacity * animation.value,
              ),
            ),
          ),
        ),
        ClipPath(
          clipper: _pushedPageClipper,
          child: super.buildTransitions(
            context,
            animation,
            secondaryAnimation,
            child,
          ),
        ),
      ],
    );
  }
}

const double _pushedPageScrimOpacity = 0.18;

const double _screenCornerRadius = 28;

const ShapeBorderClipper _pushedPageClipper = ShapeBorderClipper(
  shape: RoundedSuperellipseBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(_screenCornerRadius),
      bottomLeft: Radius.circular(_screenCornerRadius),
    ),
  ),
);

class CommonDesktopRoute<T> extends PageRoute<T> {
  final Widget Function(BuildContext context) builder;

  CommonDesktopRoute({
    required this.builder,
    this.maintainState = true,
  });

  @override
  final bool maintainState;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget result = builder(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: FadeTransition(opacity: animation, child: result),
    );
  }

  @override
  Duration get transitionDuration => Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: 200);
}
