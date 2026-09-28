import 'package:bett_box/common/system.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'package:flutter/material.dart';

const _duration = Duration(milliseconds: 500);
const double _dimAmount = 0.55;
const double _fallbackCornerRadius = 28.0;
final Curve _dimCurve = Curves.linearToEaseOut;

double _screenCornerRadius = 0;

double get screenCornerRadius =>
    _screenCornerRadius > 0 ? _screenCornerRadius : _fallbackCornerRadius;

Future<void> loadScreenCornerRadius() async {
  if (!system.isAndroid) return;
  final int radiusPx;
  try {
    radiusPx = await app.getDisplayCornerRadius();
  } catch (_) {
    return;
  }
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (radiusPx <= 0 || views.isEmpty) return;
  _screenCornerRadius = radiusPx / views.first.devicePixelRatio;
}

/// Cupertino transition + leading corner rounding + covered page dimming.
Widget buildPageTransition<T>(
  PageRoute<T> route,
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final double radius =
      system.isAndroid && animation.isAnimating ? screenCornerRadius : 0.0;
  final Widget clipped = ClipRRect(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
    ),
    child: child,
  );
  final Widget transition = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    clipped,
  );
  return _DimTransition(animation: secondaryAnimation, child: transition);
}

class _DimTransition extends AnimatedWidget {
  const _DimTransition({
    required this.animation,
    required this.child,
  }) : super(listenable: animation);

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double progress = _dimCurve.transform(animation.value);
    if (progress <= 0) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: _dimAmount * progress),
      ),
      child: child,
    );
  }
}

class PageTransitionBuilder extends PageTransitionsBuilder {
  const PageTransitionBuilder();

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildPageTransition<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
