import 'dart:math' as math;

import 'package:bett_box/common/icons.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:flutter/material.dart';

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

class _RadialClipper extends CustomClipper<Path> {
  final double progress;

  const _RadialClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (progress <= 0.0) return path;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) /
        2 *
        1.15;
    path.addOval(Rect.fromCircle(center: center, radius: maxRadius * progress));
    return path;
  }

  @override
  bool shouldReclip(_RadialClipper oldClipper) =>
      oldClipper.progress != progress;
}

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
    duration: const Duration(milliseconds: 320),
    value: widget.selected ? 1.0 : 0.0,
  );
  late final CurvedAnimation _fill = CurvedAnimation(
    parent: _fillController,
    curve: Curves.easeInOutCubic,
  );
  late final AnimationController _popController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
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
        final fillProgress = _fill.value;
        final pop = _popController.isAnimating
            ? math.sin(math.pi * _popController.value) * 0.12
            : 0.0;
        final targetColor =
            widget.color ?? IconTheme.of(context).color ?? Colors.black;

        return Transform.scale(
          scale: 1.0 + pop,
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (fillProgress < 1.0)
                  Transform.scale(
                    scale: math.max(0.001, 1.0 - 0.12 * fillProgress),
                    child: Opacity(
                      opacity: (1.0 - fillProgress * 1.4).clamp(0.0, 1.0),
                      child: Icon(
                        widget.label.regularNavIcon,
                        size: widget.size,
                        color: targetColor,
                      ),
                    ),
                  ),
                if (fillProgress > 0.0)
                  ClipPath(
                    clipper: _RadialClipper(fillProgress),
                    child: Transform.scale(
                      scale: 0.88 + 0.12 * fillProgress,
                      child: Icon(
                        widget.label.filledNavIcon,
                        size: widget.size,
                        color: targetColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
