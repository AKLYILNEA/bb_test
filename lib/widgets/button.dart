import 'dart:math' as math;

import 'package:bett_box/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

enum TonalButtonSize {
  bar(button: 40, icon: 22),
  section(button: 36, icon: 20),
  compact(button: 32, icon: 20);

  const TonalButtonSize({required this.button, required this.icon});

  final double button;
  final double icon;
}

class TonalButtonGroup extends StatelessWidget {
  const TonalButtonGroup({
    super.key,
    this.size = TonalButtonSize.bar,
    required this.children,
  });

  final TonalButtonSize size;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ElasticPress(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.colorScheme.secondaryContainer,
          shape: const SuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        child: TonalButtonTheme(
          grouped: true,
          size: size,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class TonalButtonTheme extends StatelessWidget {
  const TonalButtonTheme({
    super.key,
    this.grouped = false,
    this.size = TonalButtonSize.bar,
    required this.child,
  });

  final bool grouped;
  final TonalButtonSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final fill = grouped ? Colors.transparent : colorScheme.secondaryContainer;
    final foreground = colorScheme.onSecondaryContainer;
    final disabledForeground = foreground.withValues(alpha: 0.38);
    ButtonStyle feedback(Color? tint) => ButtonStyle(
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty<Color?>.fromMap({
        if (tint != null) WidgetState.focused: tint.withValues(alpha: 0.1),
        WidgetState.pressed: Colors.transparent,
        if (tint != null) WidgetState.hovered: tint.withValues(alpha: 0.08),
      }),
    );
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: feedback(foreground).merge(
          IconButton.styleFrom(
            backgroundColor: fill,
            foregroundColor: foreground,
            disabledBackgroundColor: fill,
            disabledForegroundColor: disabledForeground,
            fixedSize: Size.square(size.button),
            minimumSize: Size.square(size.button),
            padding: EdgeInsets.zero,
            iconSize: size.icon,
            shape: const SuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: FilledButtonTheme(
        data: FilledButtonThemeData(
          style: feedback(grouped ? foreground : null).merge(
            FilledButton.styleFrom(
              backgroundColor: grouped ? fill : null,
              foregroundColor: grouped ? foreground : null,
              disabledBackgroundColor: grouped ? fill : null,
              disabledForegroundColor: grouped ? disabledForeground : null,
              minimumSize: Size.square(size.button),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const SuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        child: IconTheme.merge(
          data: const IconThemeData(fill: 1),
          child: child,
        ),
      ),
    );
  }
}

class ElasticPress extends StatefulWidget {
  const ElasticPress({super.key, this.enabled = true, required this.child});

  static const buttonStyle = ButtonStyle(
    splashFactory: NoSplash.splashFactory,
    overlayColor: WidgetStateProperty<Color?>.fromMap({
      WidgetState.pressed: Colors.transparent,
    }),
  );

  final bool enabled;
  final Widget child;

  @override
  State<ElasticPress> createState() => _ElasticPressState();
}

class _ElasticPressState extends State<ElasticPress>
    with TickerProviderStateMixin {
  late final _Spring _lift = _Spring(this, 0);
  late final _Spring _pullX = _Spring(this, 0);
  late final _Spring _pullY = _Spring(this, 0);
  late final Listenable _motion = Listenable.merge([_lift, _pullX, _pullY]);
  int? _pointer;
  Offset _origin = Offset.zero;

  @override
  void dispose() {
    _lift.dispose();
    _pullX.dispose();
    _pullY.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled ||
        _pointer != null ||
        event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _origin = event.localPosition;
    _lift.springTo(1, _liftSpring);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    final shortest = renderBox?.hasSize == true
        ? renderBox!.size.shortestSide
        : 40.0;
    final limit = shortest * _pullLimit;
    final pull = event.localPosition - _origin;
    _pullX.springTo(_rubberBand(pull.dx, limit), _trackSpring);
    _pullY.springTo(_rubberBand(pull.dy, limit), _trackSpring);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    _lift.springTo(0, _settleSpring);
    _pullX.springTo(0, _settleSpring);
    _pullY.springTo(0, _settleSpring);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (_, child) => _PressTransform(
          lift: _lift.value,
          pull: Offset(_pullX.value, _pullY.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class ElasticButton extends StatelessWidget {
  const ElasticButton({super.key, this.enabled = true, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElasticPress(
      enabled: enabled,
      child: Theme(
        data: theme.copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: IconTheme(
          data: IconTheme.of(context),
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: ElasticPress.buttonStyle.merge(
                IconButtonTheme.of(context).style,
              ),
            ),
            child: FilledButtonTheme(
              data: FilledButtonThemeData(
                style: ElasticPress.buttonStyle.merge(
                  FilledButtonTheme.of(context).style,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

const double _pressGrowth = 1 / 8;
const double _maxPressGrowth = 16;
const double _pullLimit = 7 / 32;
const double _pullStretch = 0.5;

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

double _rubberBand(double overshoot, double limit) {
  if (limit <= 0) return 0;
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
    final swell = 1 +
        _lift *
            math.min(_pressGrowth * 2,
                size.longestSide > 0 ? _maxPressGrowth / size.longestSide : 0.2);
    final scaleX = swell *
        (1 + (size.width > 0 ? _pull.dx.abs() / size.width * _pullStretch : 0));
    final scaleY = swell *
        (1 + (size.height > 0 ? _pull.dy.abs() / size.height * _pullStretch : 0));
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
