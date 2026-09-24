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
        return FluentIcons.calendar_agenda_24_regular;
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
        return FluentIcons.calendar_agenda_24_filled;
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
  final IconData regularIcon;
  final IconData filledIcon;
  final bool selected;
  final Color? color;
  final double size;

  const AnimatedNavIcon({
    super.key,
    required this.regularIcon,
    required this.filledIcon,
    required this.selected,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _crossFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.selected ? 1.0 : 0.0,
    );
    _crossFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _crossFadeAnimation.value;
        final pop = _controller.status == AnimationStatus.forward
            ? math.sin(math.pi * _controller.value) * 0.12
            : 0.0;
        final scale = 1.0 + pop;
        final targetColor = widget.color ?? IconTheme.of(context).color;

        Widget iconWidget;
        if (progress >= 1.0) {
          iconWidget = Icon(
            widget.filledIcon,
            size: widget.size,
            color: targetColor,
          );
        } else if (progress <= 0.0) {
          iconWidget = Icon(
            widget.regularIcon,
            size: widget.size,
            color: targetColor,
          );
        } else {
          iconWidget = Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1.0 - progress).clamp(0.0, 1.0),
                child: Icon(
                  widget.regularIcon,
                  size: widget.size,
                  color: targetColor,
                ),
              ),
              Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: Icon(
                  widget.filledIcon,
                  size: widget.size,
                  color: targetColor,
                ),
              ),
            ],
          );
        }

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(child: iconWidget),
          ),
        );
      },
    );
  }
}
