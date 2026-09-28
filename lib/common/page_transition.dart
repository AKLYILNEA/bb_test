import 'dart:math' as math;

import 'package:bett_box/common/system.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'package:flutter/material.dart';

const _duration = Duration(milliseconds: 500);
const double _dimAmount = 0.55;
const double _fallbackCornerRadius = 28.0;

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

/// Step response of an underdamped spring (response 0.8, damping 0.95).
class PageTransitionCurve extends Curve {
  const PageTransitionCurve();

  static const double _response = 0.8;
  static const double _damping = 0.95;

  static final double _omega = 2 * math.pi / _response;
  static final double _k = _omega * _omega;
  static final double _c = _damping * 4 * math.pi / _response;
  static final double _w = math.sqrt(4 * _k - _c * _c) / 2;
  static final double _r = -_c / 2;
  static final double _c2 = _r / _w;

  @override
  double transformInternal(double t) =>
      math.exp(_r * t) * (-math.cos(_w * t) + _c2 * math.sin(_w * t)) + 1;
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
  // The covered page is kept still: the slide owns the movement only.
  final Widget slide = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
    route,
    context,
    animation,
    kAlwaysDismissedAnimation,
    clipped,
  );
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[
      _DimScrim(animation: animation),
      slide,
    ],
  );
}

/// Dims the page below while this route is moving. Driven by the route's own
/// animation, so it never follows a proxy animation that swaps mid-flight.
class _DimScrim extends StatefulWidget {
  const _DimScrim({required this.animation});

  final Animation<double> animation;

  @override
  State<_DimScrim> createState() => _DimScrimState();
}

class _DimScrimState extends State<_DimScrim> {
  static const Curve _curve = PageTransitionCurve();
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: widget.animation,
    curve: _curve,
    reverseCurve: _curve.flipped,
  );

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        if (!widget.animation.isAnimating) return const SizedBox.shrink();
        final double progress = _progress.value;
        if (progress <= 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: _dimAmount * progress),
          ),
        );
      },
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
