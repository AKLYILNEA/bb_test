import 'package:bett_box/common/common.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

const _kSpring = SpringDescription(mass: 1.0, stiffness: 180.0, damping: 20.0);
const _kMaxDelta = 120.0;

class DesktopSmoothScroll extends StatefulWidget {
  final ScrollController controller;
  final Widget child;
  final double scrollSpeed;

  const DesktopSmoothScroll({
    super.key,
    required this.controller,
    required this.child,
    this.scrollSpeed = 2.0,
  });

  @override
  State<DesktopSmoothScroll> createState() => _DesktopSmoothScrollState();
}

class _DesktopSmoothScrollState extends State<DesktopSmoothScroll> with SingleTickerProviderStateMixin {
  double _futurePosition = 0;

  late final _anim = AnimationController.unbounded(vsync: this)..addListener(_onTick);

  void _onTick() {
    if (!widget.controller.hasClients) return;

    final pos = widget.controller.position;
    final val = _anim.value.clamp(pos.minScrollExtent, pos.maxScrollExtent);

    if ((val - pos.pixels).abs() > 0.01) {
      pos.setPixels(val);
      pos.didUpdateScrollPositionBy(val - pos.pixels);
    }
    
    if ((val - pos.minScrollExtent).abs() < 0.01 || (val - pos.maxScrollExtent).abs() < 0.01) {
      _anim.stop();
    }
  }

  void _handleSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || e.kind == PointerDeviceKind.trackpad || !widget.controller.hasClients) return;

    final pos = widget.controller.position;
    final delta = (-e.scrollDelta.dy * widget.scrollSpeed).clamp(-_kMaxDelta, _kMaxDelta);

    final atMaxExtent = (pos.pixels - pos.maxScrollExtent).abs() < 1.0;
    final atMinExtent = (pos.pixels - pos.minScrollExtent).abs() < 1.0;
    
    if ((atMaxExtent && delta > 0) || (atMinExtent && delta < 0)) {
      return;
    }

    final basePosition = _anim.isAnimating ? _futurePosition : pos.pixels;
    _futurePosition = (basePosition + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);

    if ((_futurePosition - pos.pixels).abs() < 0.5) return;

    final currentVelocity = _anim.isAnimating ? _anim.velocity : 0.0;
    final clampedVelocity = currentVelocity.clamp(-2000.0, 2000.0);
    
    _anim.stop();
    _anim.value = pos.pixels;
    _anim.animateWith(SpringSimulation(_kSpring, pos.pixels, _futurePosition, clampedVelocity));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!system.isDesktop) return widget.child;

    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        if (_anim.isAnimating && n.direction != ScrollDirection.idle) _anim.stop();
        return false;
      },
      child: Listener(
        onPointerSignal: _handleSignal,
        child: widget.child,
      ),
    );
  }
}
