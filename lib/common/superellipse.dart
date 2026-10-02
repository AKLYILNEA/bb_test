import 'package:flutter/material.dart';

/// Rounded superellipse that always paints through a [Path].
///
/// Skia (windows / linux / macos) has no native rounded superellipse: the
/// engine falls back to a plain rounded rectangle for filled
/// [Canvas.drawRSuperellipse] calls, so solid [ShapeDecoration] surfaces lose
/// their continuous corners on desktop while Impeller keeps them. Building the
/// outline as a path renders the exact curve on every backend.
class SuperellipseBorder extends RoundedSuperellipseBorder {
  const SuperellipseBorder({super.side, super.borderRadius});

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }

  @override
  SuperellipseBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return SuperellipseBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return SuperellipseBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    return _keepSuperellipse(super.lerpFrom(a, t));
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    return _keepSuperellipse(super.lerpTo(b, t));
  }

  static ShapeBorder? _keepSuperellipse(ShapeBorder? border) {
    if (border is RoundedSuperellipseBorder) {
      return SuperellipseBorder(
        side: border.side,
        borderRadius: border.borderRadius,
      );
    }
    return border;
  }
}
