import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/animated_nav_icon.dart';
import 'package:bett_box/widgets/card.dart';

const double _barHeight = 65.0;
const double _barPadding = 6.0;
const double _overdrag = 0.25;

final _trackSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 120),
);
final _liftSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 280),
  bounce: 0.15,
);
final _settleSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 320),
  bounce: 0.12,
);

double _rubberBand(double overshoot, double limit) {
  final pull = 1 - 1 / (overshoot.abs() * 0.55 / limit + 1);
  return limit * pull * overshoot.sign;
}

class _Spring extends ChangeNotifier implements ValueListenable<double> {
  _Spring(TickerProvider vsync, this._value) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double _value;
  double _target = 0;
  SpringSimulation? _simulation;
  double _now = 0;
  double _start = 0;

  @override
  double get value => _value;

  double get target => _simulation == null ? _value : _target;

  double get velocity => _simulation?.dx(_now - _start) ?? 0;

  void springTo(double target, SpringDescription spring) {
    _simulation = SpringSimulation(spring, _value, target, velocity);
    _target = target;
    if (_ticker.isActive) {
      _start = _now;
      return;
    }
    _now = _start = 0;
    _ticker.start();
  }

  void jumpTo(double value) {
    _simulation = null;
    _ticker.stop();
    _value = value;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _now = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final simulation = _simulation!;
    final time = _now - _start;
    if (simulation.isDone(time)) {
      _value = _target;
      _simulation = null;
      _ticker.stop();
    } else {
      _value = simulation.x(time);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class GoogleBottomNavBar extends ConsumerStatefulWidget {
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  const GoogleBottomNavBar({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  ConsumerState<GoogleBottomNavBar> createState() => _GoogleBottomNavBarState();
}

class _GoogleBottomNavBarState extends ConsumerState<GoogleBottomNavBar>
    with TickerProviderStateMixin {
  late final _Spring _lens = _Spring(this, _selectedIndex.toDouble());
  late final _Spring _lift = _Spring(this, 0);
  late final Listenable _motion = Listenable.merge([_lens, _lift]);

  int? _pointer;
  int? _pressedIndex;
  double _pressX = 0;
  bool _dragging = false;
  int _lastSnappedIndex = 0;
  int _lastHapticTime = 0;

  int get _lastIndex => math.max(0, widget.navigationItems.length - 1);

  int get _selectedIndex => widget.selectedIndex.clamp(0, _lastIndex);

  @override
  void initState() {
    super.initState();
    _lastSnappedIndex = _selectedIndex;
  }

  @override
  void didUpdateWidget(covariant GoogleBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pressedIndex == null &&
        (_lens.target != _selectedIndex ||
            oldWidget.selectedIndex != widget.selectedIndex)) {
      _lastSnappedIndex = _selectedIndex;
      _lens.springTo(_selectedIndex.toDouble(), _settleSpring);
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _triggerHapticFeedback(bool enableFeedback) {
    if (system.isAndroid && enableFeedback) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastHapticTime > 35) {
        _lastHapticTime = now;
        HapticFeedback.selectionClick();
      }
    }
  }

  double _positionAt(Offset localPosition) {
    final width = context.size?.width ?? 0;
    final innerWidth = width - (2 * _barPadding);
    if (innerWidth <= 0 || widget.navigationItems.isEmpty) {
      return widget.selectedIndex.toDouble();
    }
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final dx = isRtl ? (width - localPosition.dx) : localPosition.dx;
    final localInnerDx = dx - _barPadding;
    final count = math.max(1, widget.navigationItems.length);
    final extent = innerWidth / count;
    final position = (localInnerDx / extent) - 0.5;
    if (position < 0) {
      return _rubberBand(position, _overdrag);
    }
    if (position > _lastIndex) {
      return _lastIndex + _rubberBand(position - _lastIndex, _overdrag);
    }
    return position;
  }

  int _indexAt(double position) => position.round().clamp(0, _lastIndex);

  void _handlePointerDown(PointerDownEvent event, bool enableFeedback) {
    if (_pointer != null || event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _pressX = event.localPosition.dx;
    _press(event.localPosition, enableFeedback);
  }

  void _handlePointerMove(PointerMoveEvent event, bool enableFeedback) {
    if (event.pointer == _pointer) {
      _slide(event.localPosition, enableFeedback);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    _release(commit: event is PointerUpEvent);
  }

  void _press(Offset localPosition, bool enableFeedback) {
    if (widget.navigationItems.isEmpty) {
      return;
    }
    final position = _positionAt(localPosition);
    final index = _indexAt(position);
    _pressedIndex = index;
    _lastSnappedIndex = index;
    _pressX = localPosition.dx;
    _dragging = false;
    _lift.springTo(1, _liftSpring);
    _lens.springTo(index.toDouble(), _settleSpring);
    _triggerHapticFeedback(enableFeedback);
  }

  void _slide(Offset localPosition, bool enableFeedback) {
    if (_pressedIndex == null) {
      return;
    }
    if (!_dragging) {
      if ((localPosition.dx - _pressX).abs() < kTouchSlop) {
        return;
      }
      _dragging = true;
    }
    final position = _positionAt(localPosition);
    _lens.springTo(position, _trackSpring);
    final index = _indexAt(position);
    if (index != _lastSnappedIndex) {
      _triggerHapticFeedback(enableFeedback);
      _lastSnappedIndex = index;
    }
    _pressedIndex = index;
  }

  void _release({required bool commit}) {
    final index = _pressedIndex;
    if (index == null) {
      return;
    }
    _pressedIndex = null;
    _dragging = false;
    _lift.springTo(0, _settleSpring);
    if (!commit) {
      _lens.springTo(_selectedIndex.toDouble(), _settleSpring);
      return;
    }
    _lens.springTo(index.toDouble(), _settleSpring);
    if (index != widget.selectedIndex) {
      widget.onTabChange(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enableFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );
    final colorScheme = context.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;

    final barColor = commonCardColor(context).withValues(
      alpha: isLight ? 0.88 : 0.86,
    );
    final borderColor = isLight
        ? colorScheme.outlineVariant.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.14);

    final count = widget.navigationItems.length;

    final bar = SizedBox(
      height: _barHeight,
      child: Container(
        decoration: ShapeDecoration(
          shape: SuperellipseBorder(
            borderRadius: BorderRadius.circular(32.5),
          ),
          shadows: [
            BoxShadow(
              blurRadius: 28,
              offset: const Offset(0, 8),
              color: Colors.black.withValues(
                alpha: isLight ? 0.08 : 0.22,
              ),
            ),
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(
                alpha: isLight ? 0.04 : 0.10,
              ),
            ),
          ],
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: SuperellipseBorder(
              borderRadius: BorderRadius.circular(32.5),
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 8.0,
              sigmaY: 8.0,
            ),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: barColor,
                shape: SuperellipseBorder(
                  borderRadius: BorderRadius.circular(32.5),
                  side: BorderSide(
                    color: borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final innerWidth = totalWidth - (2 * _barPadding);
                  final slotWidth = innerWidth / math.max(1, count);

                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _handlePointerDown(e, enableFeedback),
                    onPointerMove: (e) => _handlePointerMove(e, enableFeedback),
                    onPointerUp: _handlePointerEnd,
                    onPointerCancel: _handlePointerEnd,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (count > 0)
                            AnimatedBuilder(
                              animation: _motion,
                              builder: (context, _) => _Lens(
                                position: _lens.value,
                                lift: _lift.value,
                                slotWidth: slotWidth,
                                totalHeight: _barHeight,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _barPadding,
                            ),
                            child: Row(
                              children: [
                                for (final (index, item)
                                    in widget.navigationItems.indexed)
                                  Expanded(
                                    child: _FloatingBarItem(
                                      item: item,
                                      index: index,
                                      lens: _lens,
                                      lift: _lift,
                                      onActivate: () {
                                        widget.onTabChange(index);
                                        _lens.springTo(
                                          index.toDouble(),
                                          _settleSpring,
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: math.max(viewBottom, 12.0)),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          child: bar,
        ),
      ),
    );
  }
}

class _Lens extends StatelessWidget {
  const _Lens({
    required this.position,
    required this.lift,
    required this.slotWidth,
    required this.totalHeight,
  });

  final double position;
  final double lift;
  final double slotWidth;
  final double totalHeight;

  @override
  Widget build(BuildContext context) {
    final clampedLift = lift.clamp(0.0, 1.0);
    final currentGap = _barPadding * (1.0 - clampedLift);
    final lensHeight = totalHeight - 2 * currentGap;
    final lensRadius = lensHeight / 2;
    final lensWidth = slotWidth + 2 * _barPadding * clampedLift;
    final centerDx = _barPadding + (position + 0.5) * slotWidth;
    final start = centerDx - lensWidth / 2;
    final top = currentGap;

    final colorScheme = context.colorScheme;
    final lensColor = Color.alphaBlend(
      colorScheme.onSecondaryContainer.withValues(
        alpha: 0.08 * clampedLift,
      ),
      colorScheme.secondaryContainer,
    );

    return PositionedDirectional(
      start: start,
      top: top,
      width: lensWidth,
      height: lensHeight,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: lensColor,
          shape: SuperellipseBorder(
            borderRadius: BorderRadius.circular(lensRadius),
          ),
        ),
      ),
    );
  }
}

class _FloatingBarItem extends StatelessWidget {
  const _FloatingBarItem({
    required this.item,
    required this.index,
    required this.lens,
    required this.lift,
    required this.onActivate,
  });

  final NavigationItem item;
  final int index;
  final ValueListenable<double> lens;
  final ValueListenable<double> lift;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([lens, lift]),
      builder: (context, _) {
        final emphasis = (1.0 - (lens.value - index).abs()).clamp(0.0, 1.0);
        final currentLift = lift.value.clamp(0.0, 1.0);
        final color = Color.lerp(
          colorScheme.onSurfaceVariant,
          colorScheme.primary,
          emphasis,
        )!;
        final scale = 1.0 + 0.10 * emphasis + 0.05 * emphasis * currentLift;

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.label.filledNavIcon,
                  size: 24.0,
                  color: color,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label.localizedName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.normal,
                    color: color,
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
