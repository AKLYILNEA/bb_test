import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:bett_box/common/icons.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

enum GlyphRole { body, detail, line }

sealed class CustomGlyphShape {
  final GlyphRole role;
  final bool solid;

  const CustomGlyphShape({this.role = GlyphRole.body, this.solid = false});

  Path get path;
}

class CustomGlyphBox extends CustomGlyphShape {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double radius;

  const CustomGlyphBox(
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.radius, {
    super.role,
    super.solid,
  });

  @override
  Path get path => Path()
    ..addRRect(
      RRect.fromLTRBR(left, top, right, bottom, Radius.circular(radius)),
    );
}

class CustomGlyphCircle extends CustomGlyphShape {
  final double x;
  final double y;
  final double radius;

  const CustomGlyphCircle(
    this.x,
    this.y,
    this.radius, {
    super.role,
    super.solid,
  });

  @override
  Path get path =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: radius));
}

class CustomGlyphOval extends CustomGlyphShape {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const CustomGlyphOval(
    this.left,
    this.top,
    this.right,
    this.bottom, {
    super.role,
    super.solid,
  });

  @override
  Path get path => Path()..addOval(Rect.fromLTRB(left, top, right, bottom));
}

class CustomGlyphArc extends CustomGlyphShape {
  final double x;
  final double y;
  final double radius;
  final double start;
  final double sweep;

  const CustomGlyphArc(
    this.x,
    this.y,
    this.radius,
    this.start,
    this.sweep, {
    super.role,
    super.solid,
  });

  @override
  Path get path => Path()
    ..addArc(
      Rect.fromCircle(center: Offset(x, y), radius: radius),
      start,
      sweep,
    );
}

class GlyphVertex {
  final double x;
  final double y;
  final double radius;

  const GlyphVertex(this.x, this.y, [this.radius = 0]);

  Offset get offset => Offset(x, y);
}

class CustomGlyphPolyline extends CustomGlyphShape {
  final List<GlyphVertex> vertices;
  final bool closed;

  const CustomGlyphPolyline(
    this.vertices, {
    this.closed = false,
    super.role,
    super.solid,
  });

  (Offset, Offset) _corner(int index) {
    final count = vertices.length;
    final vertex = vertices[index].offset;
    final previous = vertices[(index - 1 + count) % count].offset;
    final next = vertices[(index + 1) % count].offset;
    final toPrevious = previous - vertex;
    final toNext = next - vertex;
    final radius = vertices[index].radius;
    return (
      vertex +
          toPrevious /
              toPrevious.distance *
              math.min(radius, toPrevious.distance / 2),
      vertex + toNext / toNext.distance * math.min(radius, toNext.distance / 2),
    );
  }

  @override
  Path get path {
    final path = Path();
    final count = vertices.length;
    final first = closed ? _corner(0).$2 : vertices.first.offset;
    path.moveTo(first.dx, first.dy);
    final last = closed ? count : count - 1;
    for (var index = 1; index <= last; index++) {
      final vertex = vertices[index % count];
      if (!closed && index == count - 1) {
        path.lineTo(vertex.x, vertex.y);
        break;
      }
      final (enter, exit) = _corner(index % count);
      path
        ..lineTo(enter.dx, enter.dy)
        ..quadraticBezierTo(vertex.x, vertex.y, exit.dx, exit.dy);
    }
    if (closed) {
      path.close();
    }
    return path;
  }
}

class CustomGlyphLink extends CustomGlyphShape {
  final Offset from;
  final Offset to;
  final double radius;

  const CustomGlyphLink(this.from, this.to, this.radius)
    : super(role: GlyphRole.line);

  @override
  Path get path {
    final delta = to - from;
    final inset = delta / delta.distance * (radius + 1.8);
    final start = from + inset;
    final end = to - inset;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
  }
}

class CustomGlyphPath extends CustomGlyphShape {
  final String data;
  static final _parsed = Expando<Path>();

  const CustomGlyphPath(this.data, {super.role, super.solid});

  @override
  Path get path => _parsed[this] ??= _parse(data);

  static Path _parse(String data) {
    final writer = _PathWriter();
    writeSvgPathDataToPath(data, writer);
    return writer.path;
  }
}

class _PathWriter implements PathProxy {
  final path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

class CustomGlyph {
  final List<CustomGlyphShape> shapes;

  const CustomGlyph(this.shapes);

  static final home = CustomGlyph([
    const CustomGlyphPolyline(
      [
        GlyphVertex(12, 2.6, 1.2),
        GlyphVertex(3.5, 9.8, 1.2),
        GlyphVertex(3.5, 20.5, 1.5),
        GlyphVertex(20.5, 20.5, 1.5),
        GlyphVertex(20.5, 9.8, 1.2),
      ],
      closed: true,
      role: GlyphRole.body,
    ),
    const CustomGlyphPolyline([
      GlyphVertex(9.5, 20.5),
      GlyphVertex(9.5, 14.5, 1.2),
      GlyphVertex(14.5, 14.5, 1.2),
      GlyphVertex(14.5, 20.5),
    ], role: GlyphRole.detail),
  ]);

  static const globe = CustomGlyph([
    CustomGlyphCircle(12, 12, 8.8, role: GlyphRole.body),
    CustomGlyphOval(8.2, 3.2, 15.8, 20.8, role: GlyphRole.detail),
    CustomGlyphPolyline([
      GlyphVertex(3.2, 12),
      GlyphVertex(20.8, 12),
    ], role: GlyphRole.detail),
  ]);

  static const archive = CustomGlyph([
    CustomGlyphBox(3.5, 3.2, 20.5, 7.5, 1.8, role: GlyphRole.body),
    CustomGlyphBox(4.5, 8.5, 19.5, 20.8, 2.2, role: GlyphRole.body),
    CustomGlyphBox(9.5, 11.2, 14.5, 13.2, 1.0, role: GlyphRole.detail),
  ]);

  static const clover = CustomGlyph([
    CustomGlyphBox(2.8, 2.8, 11.2, 11.2, 3.8, role: GlyphRole.body),
    CustomGlyphBox(12.8, 2.8, 21.2, 11.2, 3.8, role: GlyphRole.body),
    CustomGlyphBox(2.8, 12.8, 11.2, 21.2, 3.8, role: GlyphRole.body),
    CustomGlyphBox(12.8, 12.8, 21.2, 21.2, 3.8, role: GlyphRole.body),
  ]);

  static const clock = CustomGlyph([
    CustomGlyphCircle(12, 12, 8.8, role: GlyphRole.body),
    CustomGlyphPolyline([
      GlyphVertex(12, 7.5),
      GlyphVertex(12, 12, 0.6),
      GlyphVertex(15.5, 14),
    ], role: GlyphRole.detail),
  ]);

  static final connections = CustomGlyph([
    const CustomGlyphCircle(12, 5.2, 2.4, role: GlyphRole.body),
    const CustomGlyphCircle(5.2, 17.6, 2.4, role: GlyphRole.body),
    const CustomGlyphCircle(18.8, 17.6, 2.4, role: GlyphRole.body),
    const CustomGlyphLink(Offset(12, 5.2), Offset(5.2, 17.6), 2.4),
    const CustomGlyphLink(Offset(12, 5.2), Offset(18.8, 17.6), 2.4),
    const CustomGlyphLink(Offset(5.2, 17.6), Offset(18.8, 17.6), 2.4),
  ]);

  static const resources = CustomGlyph([
    CustomGlyphBox(3.5, 3.5, 20.5, 9.5, 2.0, role: GlyphRole.body),
    CustomGlyphBox(4.5, 10.5, 19.5, 20.5, 2.5, role: GlyphRole.body),
    CustomGlyphPolyline([
      GlyphVertex(9.5, 14.5),
      GlyphVertex(14.5, 14.5),
    ], role: GlyphRole.detail),
  ]);

  static const logs = CustomGlyph([
    CustomGlyphOval(6.5, 7.5, 17.5, 19.5, role: GlyphRole.body),
    CustomGlyphArc(12, 7.5, 2.5, math.pi, math.pi, role: GlyphRole.body),
    CustomGlyphPolyline([
      GlyphVertex(12, 9),
      GlyphVertex(12, 18),
    ], role: GlyphRole.detail),
    CustomGlyphPolyline([
      GlyphVertex(6.5, 10.5),
      GlyphVertex(3, 9),
    ], role: GlyphRole.line),
    CustomGlyphPolyline([
      GlyphVertex(17.5, 10.5),
      GlyphVertex(21, 9),
    ], role: GlyphRole.line),
    CustomGlyphPolyline([
      GlyphVertex(6.5, 14),
      GlyphVertex(2.5, 14),
    ], role: GlyphRole.line),
    CustomGlyphPolyline([
      GlyphVertex(17.5, 14),
      GlyphVertex(21.5, 14),
    ], role: GlyphRole.line),
    CustomGlyphPolyline([
      GlyphVertex(6.5, 17.5),
      GlyphVertex(3, 19),
    ], role: GlyphRole.line),
    CustomGlyphPolyline([
      GlyphVertex(17.5, 17.5),
      GlyphVertex(21, 19),
    ], role: GlyphRole.line),
  ]);

  static const script = CustomGlyph([
    CustomGlyphBox(3.5, 3.5, 20.5, 20.5, 3.0, role: GlyphRole.body),
    CustomGlyphPath(
      'M8 9V14C8 15.5 9 16 10.5 16M13.5 16C15 16 16 15 16 14C16 12.5 13.5 12.5 13.5 11C13.5 10 14.5 9 16 9',
      role: GlyphRole.detail,
    ),
  ]);
}

extension PageLabelNavGlyph on PageLabel {
  CustomGlyph get navGlyph {
    switch (this) {
      case PageLabel.dashboard:
        return CustomGlyph.home;
      case PageLabel.proxies:
        return CustomGlyph.globe;
      case PageLabel.profiles:
        return CustomGlyph.archive;
      case PageLabel.requests:
        return CustomGlyph.clock;
      case PageLabel.connections:
        return CustomGlyph.connections;
      case PageLabel.resources:
        return CustomGlyph.resources;
      case PageLabel.script:
        return CustomGlyph.script;
      case PageLabel.logs:
        return CustomGlyph.logs;
      case PageLabel.tools:
        return CustomGlyph.clover;
    }
  }
}

extension PageLabelNavIcons on PageLabel {
  IconData get regularNavIcon {
    switch (this) {
      case PageLabel.dashboard:
        return FluentIcons.home_24_regular;
      case PageLabel.proxies:
        return FluentIcons.globe_24_regular;
      case PageLabel.profiles:
        return FluentIcons.archive_24_regular;
      case PageLabel.requests:
        return FluentIcons.clock_24_regular;
      case PageLabel.connections:
        return FluentIcons.iot_24_regular;
      case PageLabel.resources:
        return FluentIcons.database_24_regular;
      case PageLabel.script:
        return FluentIcons.javascript_24_regular;
      case PageLabel.logs:
        return FluentIcons.bug_24_regular;
      case PageLabel.tools:
        return FluentIcons.clover_24_regular;
    }
  }

  IconData get filledNavIcon {
    switch (this) {
      case PageLabel.dashboard:
        return FluentIcons.home_24_filled;
      case PageLabel.proxies:
        return FluentIcons.globe_24_filled;
      case PageLabel.profiles:
        return FluentIcons.archive_24_filled;
      case PageLabel.requests:
        return FluentIcons.clock_24_filled;
      case PageLabel.connections:
        return FluentIcons.iot_24_filled;
      case PageLabel.resources:
        return FluentIcons.database_24_filled;
      case PageLabel.script:
        return FluentIcons.javascript_24_filled;
      case PageLabel.logs:
        return FluentIcons.bug_24_filled;
      case PageLabel.tools:
        return FluentIcons.clover_24_filled;
    }
  }
}

const _grid = Rect.fromLTWH(0, 0, 24.0, 24.0);
const _strokeWidth = 1.8;
const _fillStart = _strokeWidth / 2;
const _detailSwap = 0.5;
const _filledLineWidth = 2.2;

class CustomGlyphPainter extends CustomPainter {
  final CustomGlyph glyph;
  final double fill;
  final Color color;

  const CustomGlyphPainter({
    required this.glyph,
    required this.fill,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final opaque = color.withValues(alpha: 1.0);
    final stroke = _stroke(opaque, _strokeWidth);
    final line = _stroke(
      opaque,
      lerpDouble(_strokeWidth, _filledLineWidth, fill.clamp(0.0, 1.0))!,
    );
    final area = Paint()..color = opaque;

    Paint paintFor(CustomGlyphShape shape) => shape.solid
        ? area
        : shape.role == GlyphRole.line
        ? line
        : stroke;

    final cut = fill > _detailSwap;
    final detailScale = cut
        ? (fill - _detailSwap) / (1 - _detailSwap)
        : 1 - fill / _detailSwap;

    canvas.save();
    canvas.scale(size.shortestSide / 24.0);

    if (color.a < 1.0 || (cut && detailScale > 0)) {
      canvas.saveLayer(
        _grid,
        Paint()..color = Color.fromRGBO(0, 0, 0, color.a),
      );
    } else {
      canvas.save();
    }

    for (final shape in glyph.shapes) {
      if (shape.role == GlyphRole.body) {
        _paintFill(canvas, shape.path, opaque);
      }
    }

    if (detailScale > 0) {
      for (final shape in glyph.shapes) {
        if (shape.role == GlyphRole.detail) {
          _paintDetail(canvas, shape, opaque, detailScale, cut: cut);
        }
      }
    }

    for (final shape in glyph.shapes) {
      if (shape.role != GlyphRole.detail) {
        canvas.drawPath(shape.path, paintFor(shape));
      }
    }

    canvas.restore();
    canvas.restore();
  }

  void _paintFill(Canvas canvas, Path body, Color color) {
    if (fill <= 0) {
      return;
    }
    if (fill >= 1) {
      canvas.drawPath(body, Paint()..color = color);
      return;
    }
    final depth = body.getBounds().shortestSide / 2;
    final reach = _fillStart + (depth - _fillStart) * fill;
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(body, _stroke(color, reach * 2));
    canvas.restore();
  }

  void _paintDetail(
    Canvas canvas,
    CustomGlyphShape detail,
    Color color,
    double scale, {
    required bool cut,
  }) {
    final blendMode = cut ? BlendMode.clear : BlendMode.srcOver;
    if (!detail.solid) {
      canvas.drawPath(
        detail.path,
        _stroke(color, _strokeWidth * scale)..blendMode = blendMode,
      );
      return;
    }
    final center = detail.path.getBounds().center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(
      detail.path,
      Paint()
        ..color = color
        ..blendMode = blendMode,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph ||
      fill != oldDelegate.fill ||
      color != oldDelegate.color;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class AnimatedNavIcon extends StatefulWidget {
  final PageLabel label;
  final bool selected;
  final Color? color;
  final double size;

  const AnimatedNavIcon({
    super.key,
    required this.label,
    required this.selected,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with TickerProviderStateMixin {
  late final AnimationController _fillController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: widget.selected ? 1.0 : 0.0,
  );
  late final CurvedAnimation _fill = CurvedAnimation(
    parent: _fillController,
    curve: Curves.easeInOutCubic,
  );
  late final AnimationController _popController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Listenable _animation = Listenable.merge([_fill, _popController]);

  @override
  void didUpdateWidget(covariant AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (widget.selected) {
      _fillController.forward();
      if (!_popController.isAnimating) {
        _popController.forward(from: 0.0);
      }
    } else {
      _fillController.reverse();
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    _fillController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final pop = _popController.isAnimating
            ? math.sin(math.pi * _popController.value) * 0.1
            : 0.0;
        final targetColor =
            widget.color ?? IconTheme.of(context).color ?? Colors.black;

        return Transform.scale(
          scale: 1.0 + pop,
          child: SizedBox.square(
            dimension: widget.size,
            child: Center(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: CustomGlyphPainter(
                  glyph: widget.label.navGlyph,
                  fill: _fill.value,
                  color: targetColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
