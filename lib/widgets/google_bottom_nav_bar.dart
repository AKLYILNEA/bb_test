import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/animated_nav_icon.dart';
import 'package:bett_box/widgets/card.dart';

const double _barHeight = 64.0;
const double _lensInset = 5.0;
const double _iconSize = 24.0;
const double _labelGap = 2.0;
const double _labelInset = 2.0;
const double _labelSize = 10.0;
const double _minLabelSize = 9.0;
const double _pressGrowth = 1 / 8;
const double _maxPressGrowth = 16.0;
const double _lensGrowth = 14.0;
const double _lensMagnify = 0.12;
const double _hoverMagnet = 0.2;
const double _hoverParallax = 0.5;
const double _hoverAlpha = 0.08;
const double _hoverSwell = 0.4;
const double _jellySpeed = 8.0;
const double _jellyStretch = 0.25;
const double _overdrag = 0.35;
const double _pullLimit = 7 / 32;
const double _pullStretch = 0.5;
const double _blurSigma = 8.0;

final _trackSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 120),
);
final _liftSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 280),
  bounce: 0.2,
);
final _settleSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 500),
  bounce: 0.32,
);
final _hoverSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 260),
  bounce: 0.18,
);
final _fadeSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 200),
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

class _PressTransform extends SingleChildRenderObjectWidget {
  const _PressTransform({required this.lift, required this.pull, super.child});

  final double lift;
  final Offset pull;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPressTransform(lift: lift, pull: pull);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPressTransform renderObject,
  ) {
    renderObject
      ..lift = lift
      ..pull = pull;
  }
}

class _RenderPressTransform extends RenderProxyBox {
  _RenderPressTransform({required double lift, required Offset pull})
      : _lift = lift,
        _pull = pull;

  double _lift;
  Offset _pull;

  set lift(double value) {
    if (value == _lift) return;
    _lift = value;
    markNeedsPaint();
  }

  set pull(Offset value) {
    if (value == _pull) return;
    _pull = value;
    markNeedsPaint();
  }

  Matrix4 get _transform {
    final swell =
        1 +
        _lift * math.min(_pressGrowth * 2, _maxPressGrowth / size.longestSide);
    final scaleX = swell * (1 + _pull.dx.abs() / size.width * _pullStretch);
    final scaleY = swell * (1 + _pull.dy.abs() / size.height * _pullStretch);
    final center = size.center(Offset.zero);
    return Matrix4.diagonal3Values(scaleX, scaleY, 1)
      ..setTranslationRaw(
        center.dx * (1 - scaleX) + _pull.dx,
        center.dy * (1 - scaleY) + _pull.dy,
        0,
      );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty || (_lift == 0 && _pull == Offset.zero)) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }
}

({double width, double height}) _measureLabel(
  BuildContext context,
  String label,
  TextStyle? style,
) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  final size = (width: painter.width, height: painter.height);
  painter.dispose();
  return size;
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
  late final _Spring _hover = _Spring(this, 0);
  late final _Spring _hoverShow = _Spring(this, 0);
  late final _Spring _swell = _Spring(this, 0);
  late final _Spring _stretch = _Spring(this, 0);
  late final Listenable _barMotion = Listenable.merge([_swell, _stretch]);
  late final Listenable _motion = Listenable.merge([_lens, _lift]);
  late final Listenable _hoverMotion = Listenable.merge([_hover, _hoverShow]);

  int? _pointer;
  int? _pressedIndex;
  double _pressX = 0;
  Offset? _downPosition;
  bool _dragCancel = false;
  bool _dragging = false;
  Offset? _cursor;
  final ValueNotifier<double?> _hoverAt = ValueNotifier(null);
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
    if (_pressedIndex == null && _lens.target != _selectedIndex) {
      _lastSnappedIndex = _selectedIndex;
      _lens.springTo(_selectedIndex.toDouble(), _settleSpring);
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _lift.dispose();
    _hover.dispose();
    _hoverShow.dispose();
    _swell.dispose();
    _stretch.dispose();
    _hoverAt.dispose();
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
    if (width <= 0 || widget.navigationItems.isEmpty) {
      return widget.selectedIndex.toDouble();
    }
    final dx = Directionality.of(context) == TextDirection.ltr
        ? localPosition.dx
        : width - localPosition.dx;
    final count = math.max(1, widget.navigationItems.length);
    final slotWidth = width / count;
    final position = (dx / slotWidth) - 0.5;
    if (position < 0) {
      return _rubberBand(position, _overdrag);
    }
    if (position > _lastIndex) {
      return _lastIndex + _rubberBand(position - _lastIndex, _overdrag);
    }
    return position;
  }

  int _indexAt(double position) => position.round().clamp(0, _lastIndex);

  void _showHover() {
    final cursor = _cursor;
    if (cursor == null || _pointer != null || widget.navigationItems.isEmpty) {
      return;
    }
    final position = _positionAt(cursor);
    final index = _indexAt(position);
    final target = index + (position - index) * _hoverMagnet;
    _hoverAt.value = position;
    if (_hoverShow.target == 0 && _hoverShow.value == 0) {
      _hover.jumpTo(target);
    } else {
      _hover.springTo(target, _hoverSpring);
    }
    _hoverShow.springTo(1, _fadeSpring);
  }

  void _settleSwell() {
    final target = _cursor == null ? 0.0 : _hoverSwell;
    if (_pointer == null && _swell.target != target) {
      _swell.springTo(target, _settleSpring);
    }
  }

  void _handleHover(PointerHoverEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return;
    }
    _cursor = event.localPosition;
    _showHover();
    _settleSwell();
  }

  void _handleExit(PointerExitEvent event) {
    _cursor = null;
    _hoverShow.springTo(0, _fadeSpring);
    _hoverAt.value = null;
    _settleSwell();
  }

  void _handlePointerDown(PointerDownEvent event, bool enableFeedback) {
    if (_pointer != null || event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _pressX = event.localPosition.dx;
    _downPosition = event.localPosition;
    _dragCancel = false;
    _hoverShow.springTo(0, _fadeSpring);
    _hoverAt.value = null;
    _swell.springTo(1, _liftSpring);
    _press(event.localPosition, enableFeedback);
  }

  void _handlePointerMove(PointerMoveEvent event, bool enableFeedback) {
    if (event.pointer != _pointer || _dragCancel) {
      return;
    }
    final downPos = _downPosition;
    if (downPos != null) {
      final delta = event.localPosition - downPos;
      if (delta.dy < -50 || delta.dy > 80) {
        _dragCancel = true;
        _pointer = null;
        _pressedIndex = null;
        _dragging = false;
        _lift.springTo(0, _settleSpring);
        _swell.springTo(0, _settleSpring);
        _stretch.springTo(0, _settleSpring);
        _lens.springTo(_selectedIndex.toDouble(), _settleSpring);
        return;
      }
    }
    _slide(event.localPosition, enableFeedback);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    if (_dragCancel) {
      _dragCancel = false;
      return;
    }
    _release(commit: event is PointerUpEvent);
    _stretch.springTo(0, _settleSpring);
    _swell.springTo(0, _settleSpring);
    if (_cursor != null) {
      _cursor = event.localPosition;
      _showHover();
    }
    _settleSwell();
  }

  void _press(Offset localPosition, bool enableFeedback) {
    if (widget.navigationItems.isEmpty) {
      return;
    }
    final index = _indexAt(_positionAt(localPosition));
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
    final size = context.size!;
    final overshoot =
        localPosition.dx - localPosition.dx.clamp(0.0, size.width);
    _stretch.springTo(
      _rubberBand(overshoot, size.shortestSide * _pullLimit),
      _trackSpring,
    );
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
    final pureBlack = ref.watch(
      themeSettingProvider.select((s) => s.pureBlack),
    );
    final colorScheme = context.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final primaryColor = colorScheme.primary;
    final onSurfaceVariantColor = colorScheme.onSurfaceVariant;

    final barColor = (!pureBlack
            ? commonCardColor(context)
            : Colors.black)
        .withValues(alpha: pureBlack ? 0.95 : (isLight ? 0.88 : 0.86));
    final barBorderSide = BorderSide(
      color: isLight
          ? colorScheme.outlineVariant.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.14),
      width: 1,
    );

    final labelStyle = context.textTheme.labelSmall?.copyWith(
      fontSize: _labelSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
    final labels = [
      for (final item in widget.navigationItems)
        _measureLabel(context, item.label.localizedName, labelStyle),
    ];
    final widest = labels.fold(
      0.0,
      (width, label) => math.max(width, label.width),
    );
    final lineHeight = labels.fold(
      0.0,
      (height, label) => math.max(height, label.height),
    );

    final bar = Container(
      decoration: ShapeDecoration(
        shape: SuperellipseBorder(
          borderRadius: BorderRadius.circular(36),
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
            borderRadius: BorderRadius.circular(36),
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
          ),
          child: Container(
            height: _barHeight,
            decoration: ShapeDecoration(
              color: barColor,
              shape: SuperellipseBorder(
                borderRadius: BorderRadius.circular(36),
                side: barBorderSide,
              ),
            ),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _handlePointerDown(e, enableFeedback),
              onPointerMove: (e) => _handlePointerMove(e, enableFeedback),
              onPointerUp: _handlePointerEnd,
              onPointerCancel: _handlePointerEnd,
              child: MouseRegion(
                onHover: _handleHover,
                onExit: _handleExit,
                child: SizedBox(
                  height: _barHeight,
                  child: RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final count =
                            math.max(1, widget.navigationItems.length);
                        final slotWidth = constraints.maxWidth / count;
                        final room = slotWidth - (_labelInset * 2);
                        final labelScale = widest <= room
                            ? 1.0
                            : math.max(
                                room / widest,
                                _minLabelSize / _labelSize,
                              );

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (widget.navigationItems.isNotEmpty)
                              AnimatedBuilder(
                                animation: _motion,
                                builder: (_, _) => _Lens(
                                  position: _lens.value,
                                  velocity: _lens.velocity,
                                  slotWidth: slotWidth,
                                  barHeight: _barHeight,
                                  lensInset: _lensInset,
                                  lift: _lift.value,
                                  isLight: isLight,
                                  primaryColor: primaryColor,
                                ),
                              ),
                            if (widget.navigationItems.isNotEmpty)
                              AnimatedBuilder(
                                animation: _hoverMotion,
                                builder: (_, _) => _HoverHighlight(
                                  position: _hover.value,
                                  slotWidth: slotWidth,
                                  opacity: _hoverShow.value,
                                  barHeight: _barHeight,
                                  lensInset: _lensInset,
                                ),
                              ),
                            Row(
                              children: [
                                for (final (index, item)
                                    in widget.navigationItems.indexed)
                                  Expanded(
                                    child: _FloatingBarItem(
                                      item: item,
                                      selected: index == _selectedIndex,
                                      index: index,
                                      lens: _lens,
                                      hoverAt: _hoverAt,
                                      extent: slotWidth,
                                      lift: _lift,
                                      labelStyle: labelStyle?.copyWith(
                                        fontSize: _labelSize * labelScale,
                                      ),
                                      labelHeight: lineHeight,
                                      labelOverflows:
                                          labels[index].width * labelScale >
                                              room,
                                      onActivate: () {
                                        widget.onTabChange(index);
                                        _lens.springTo(
                                          index.toDouble(),
                                          _settleSpring,
                                        );
                                      },
                                      primaryColor: primaryColor,
                                      onSurfaceVariantColor:
                                          onSurfaceVariantColor,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
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
          child: AnimatedBuilder(
            animation: _barMotion,
            builder: (_, child) => _PressTransform(
              lift: _swell.value,
              pull: Offset(_stretch.value, 0),
              child: child,
            ),
            child: bar,
          ),
        ),
      ),
    );
  }
}

class _HoverHighlight extends StatelessWidget {
  const _HoverHighlight({
    required this.position,
    required this.slotWidth,
    required this.opacity,
    required this.barHeight,
    required this.lensInset,
  });

  final double position;
  final double slotWidth;
  final double opacity;
  final double barHeight;
  final double lensInset;

  @override
  Widget build(BuildContext context) {
    final alpha = _hoverAlpha * opacity.clamp(0.0, 1.0);
    if (alpha <= 0.001) {
      return const SizedBox.shrink();
    }
    final height = math.max(0.0, barHeight - (2 * lensInset));
    final width = math.max(0.0, slotWidth - (2 * lensInset));
    final pillRadius = height / 2;
    final centerDx = (position + 0.5) * slotWidth;
    final start = centerDx - (width / 2);

    return PositionedDirectional(
      start: start,
      top: lensInset,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.colorScheme.onSurface.withValues(alpha: alpha),
          shape: SuperellipseBorder(
            borderRadius: BorderRadius.circular(pillRadius),
          ),
        ),
      ),
    );
  }
}

class _Lens extends StatelessWidget {
  const _Lens({
    required this.position,
    required this.velocity,
    required this.slotWidth,
    required this.barHeight,
    required this.lensInset,
    required this.lift,
    required this.isLight,
    required this.primaryColor,
  });

  final double position;
  final double velocity;
  final double slotWidth;
  final double barHeight;
  final double lensInset;
  final double lift;
  final bool isLight;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final lensBaseHeight = math.max(0.0, barHeight - (2 * lensInset));
    final lensBaseWidth = math.max(0.0, slotWidth - (2 * lensInset));

    final stretch =
        (velocity.abs() / _jellySpeed).clamp(0.0, 1.0) * _jellyStretch;
    final growth = _lensGrowth * 2 * lift;
    final width = (lensBaseWidth + growth) * (1 + stretch);
    final height = (lensBaseHeight + growth) * (1 - stretch / 2);
    final pillRadius = height / 2;

    final centerDx = (position + 0.5) * slotWidth;
    final start = centerDx - (width / 2);
    final top = lensInset + (lensBaseHeight - height) / 2;

    final lensColor = isLight
        ? primaryColor.withValues(
            alpha: 0.08 + (0.05 * lift),
          )
        : primaryColor.withValues(
            alpha: 0.16 + (0.06 * lift),
          );

    return PositionedDirectional(
      start: start,
      top: top,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: lensColor,
          shape: SuperellipseBorder(
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          shadows: [
            if (lift > 0.05)
              BoxShadow(
                color: (isLight ? primaryColor : Colors.white).withValues(
                  alpha: (isLight ? 0.12 : 0.08) * lift,
                ),
                blurRadius: 12,
                offset: Offset(0, 1 * lift),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBarItem extends StatefulWidget {
  const _FloatingBarItem({
    required this.item,
    required this.selected,
    required this.index,
    required this.lens,
    required this.hoverAt,
    required this.extent,
    required this.lift,
    required this.labelStyle,
    required this.labelHeight,
    required this.labelOverflows,
    required this.onActivate,
    required this.primaryColor,
    required this.onSurfaceVariantColor,
  });

  final NavigationItem item;
  final bool selected;
  final int index;
  final ValueListenable<double> lens;
  final ValueListenable<double?> hoverAt;
  final double extent;
  final ValueListenable<double> lift;
  final TextStyle? labelStyle;
  final double labelHeight;
  final bool labelOverflows;
  final VoidCallback onActivate;
  final Color primaryColor;
  final Color onSurfaceVariantColor;

  @override
  State<_FloatingBarItem> createState() => _FloatingBarItemState();
}

class _FloatingBarItemState extends State<_FloatingBarItem>
    with SingleTickerProviderStateMixin {
  late final _Spring _parallax = _Spring(this, 0);

  @override
  void initState() {
    super.initState();
    widget.hoverAt.addListener(_followPointer);
  }

  @override
  void didUpdateWidget(covariant _FloatingBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hoverAt != widget.hoverAt) {
      oldWidget.hoverAt.removeListener(_followPointer);
      widget.hoverAt.addListener(_followPointer);
    }
    _followPointer();
  }

  @override
  void dispose() {
    widget.hoverAt.removeListener(_followPointer);
    _parallax.dispose();
    super.dispose();
  }

  void _followPointer() {
    final hoverAt = widget.hoverAt.value;
    final offset = hoverAt == null ? 0.0 : hoverAt - widget.index;
    final target = offset.abs() > 0.5
        ? 0.0
        : offset * _hoverMagnet * _hoverParallax;
    if (target != _parallax.target) {
      _parallax.springTo(target, _hoverSpring);
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _labelInset),
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.lens, widget.lift, _parallax]),
        builder: (context, _) {
          final emphasis = (1 - (widget.lens.value - widget.index).abs()).clamp(
            0.0,
            1.0,
          );
          final color = Color.lerp(
            widget.onSurfaceVariantColor,
            widget.primaryColor,
            emphasis,
          )!;

          final column = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedNavIcon(
                label: widget.item.label,
                selected: widget.selected,
                color: color,
                size: _iconSize,
              ),
              const SizedBox(height: _labelGap),
              SizedBox(
                height: widget.labelHeight,
                child: Center(
                  child: Text(
                    widget.item.label.localizedName,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: widget.labelStyle?.copyWith(color: color),
                  ),
                ),
              ),
            ],
          );

          return Transform.translate(
            offset: Offset(_parallax.value * widget.extent * direction, 0),
            transformHitTests: false,
            child: Transform.scale(
              scale: 1 + _lensMagnify * emphasis * widget.lift.value,
              child: column,
            ),
          );
        },
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        container: true,
        button: true,
        selected: widget.selected,
        label: widget.item.label.localizedName,
        excludeSemantics: true,
        onTap: widget.onActivate,
        child: widget.labelOverflows
            ? Tooltip(message: widget.item.label.localizedName, child: content)
            : content,
      ),
    );
  }
}
