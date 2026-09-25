import 'dart:math' as math;

import 'package:bett_box/enum/enum.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
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
        return FluentIcons.document_one_page_24_regular;
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
        return FluentIcons.document_one_page_24_filled;
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

  Color? _activeColor;
  Color? _inactiveColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeColor =
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).colorScheme.primary;
    if (widget.color != null) {
      if (widget.selected) {
        _activeColor = widget.color!;
        _inactiveColor ??= themeColor;
      } else {
        _inactiveColor = widget.color!;
        _activeColor ??= primaryColor;
      }
    } else {
      _activeColor = primaryColor;
      _inactiveColor = themeColor;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != null) {
      if (widget.selected) {
        _activeColor = widget.color!;
      } else {
        _inactiveColor = widget.color!;
      }
    }
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
            ? math.sin(math.pi * _popController.value) * 0.12
            : 0.0;
        final active = _activeColor ?? Theme.of(context).colorScheme.primary;
        final inactive =
            _inactiveColor ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.onSurfaceVariant;
        final currentColor = Color.lerp(inactive, active, _fill.value)!;
        final fillProgress = _fill.value;

        return Transform.scale(
          scale: 1.0 + pop,
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  widget.label.regularNavIcon,
                  size: widget.size,
                  color: currentColor,
                ),
                if (fillProgress > 0.0)
                  Opacity(
                    opacity: fillProgress,
                    child: Icon(
                      widget.label.filledNavIcon,
                      size: widget.size,
                      color: currentColor,
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
