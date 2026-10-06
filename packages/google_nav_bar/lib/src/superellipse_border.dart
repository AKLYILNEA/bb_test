import 'package:flutter/material.dart';

/// Mirrors bett_box's `lib/common/superellipse.dart` (packages cannot import
/// the host app), so the tab pill keeps a continuous-curvature outline.
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
