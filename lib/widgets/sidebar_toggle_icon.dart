import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PanelLeftTextPainter extends CustomPainter {
  final double progress;
  final Color color;

  const PanelLeftTextPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final dividerLeft = ui.lerpDouble(8.5, 14.0, progress)!;
    final dividerRight = dividerLeft + 1.5;
    final pillRight = ui.lerpDouble(7.5, 13.0, progress)!;

    final framePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(2.0, 4.0, 22.0, 20.0),
          const Radius.circular(3.25),
        ),
      )
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(3.5, 5.5, dividerLeft, 18.5),
          topLeft: const Radius.circular(1.75),
          bottomLeft: const Radius.circular(1.75),
        ),
      )
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(dividerRight, 5.5, 20.5, 18.5),
          topRight: const Radius.circular(1.75),
          bottomRight: const Radius.circular(1.75),
        ),
      );

    canvas.drawPath(framePath, paint);

    for (final cy in const [8.5, 12.0, 15.5]) {
      final pillRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(4.75, cy - 0.75, pillRight, cy + 0.75),
        const Radius.circular(0.75),
      );
      canvas.drawRRect(pillRRect, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PanelLeftTextPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

class SidebarToggleIcon extends StatefulWidget {
  final bool expanded;
  final Color? color;
  final double size;

  const SidebarToggleIcon({
    super.key,
    required this.expanded,
    this.color,
    this.size = 20.0,
  });

  @override
  State<SidebarToggleIcon> createState() => _SidebarToggleIconState();
}

class _SidebarToggleIconState extends State<SidebarToggleIcon>
    with TickerProviderStateMixin {
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.expanded ? 1.0 : 0.0,
  );
  late final CurvedAnimation _progressAnimation = CurvedAnimation(
    parent: _progressController,
    curve: Curves.easeInOutCubic,
  );
  late final AnimationController _popController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Listenable _listenable = Listenable.merge([
    _progressAnimation,
    _popController,
  ]);

  @override
  void didUpdateWidget(covariant SidebarToggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      if (widget.expanded) {
        _progressController.forward();
      } else {
        _progressController.reverse();
      }
      if (!_popController.isAnimating) {
        _popController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _progressAnimation.dispose();
    _progressController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetColor =
        widget.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _listenable,
      builder: (context, _) {
        final pop = _popController.isAnimating
            ? math.sin(math.pi * _popController.value) * 0.1
            : 0.0;
        return Transform.scale(
          scale: 1.0 + pop,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: PanelLeftTextPainter(
              progress: _progressAnimation.value,
              color: targetColor,
            ),
          ),
        );
      },
    );
  }
}
