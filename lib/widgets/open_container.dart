import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:bett_box/widgets/drag_back.dart';

typedef CloseContainerActionCallback<S> = void Function({S? returnValue});
typedef OpenContainerBuilder<S> =
    Widget Function(
      BuildContext context,
      CloseContainerActionCallback<S> action,
    );
typedef CloseContainerBuilder =
    Widget Function(BuildContext context, VoidCallback action);

enum ContainerTransitionType { fade, fadeThrough }

typedef ClosedCallback<S> = void Function(S data);

@optionalTypeArgs
class OpenContainer<T extends Object?> extends StatefulWidget {
  const OpenContainer({
    super.key,
    this.closedColor,
    this.openColor,
    this.middleColor,
    this.closedShape,
    this.openShape,
    this.onClosed,
    required this.closedBuilder,
    required this.openBuilder,
    this.tappable = true,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.transitionType = ContainerTransitionType.fade,
    this.curve = Curves.fastOutSlowIn,
    this.useRootNavigator = false,
    this.routeSettings,
    this.clipBehavior = Clip.antiAlias,
  });

  final Color? closedColor;
  final Color? openColor;
  final Color? middleColor;
  final ShapeBorder? closedShape;
  final ShapeBorder? openShape;
  final ClosedCallback<T?>? onClosed;
  final CloseContainerBuilder closedBuilder;
  final OpenContainerBuilder<T> openBuilder;
  final bool tappable;
  final Duration transitionDuration;
  final ContainerTransitionType transitionType;
  final Curve curve;
  final bool useRootNavigator;
  final RouteSettings? routeSettings;
  final Clip clipBehavior;

  @override
  State<OpenContainer<T?>> createState() => _OpenContainerState<T>();
}

class _OpenContainerState<T> extends State<OpenContainer<T?>> {
  final GlobalKey<_HideableState> _sourceKey = GlobalKey<_HideableState>();

  Future<void> openContainer() async {
    final Color middleColor =
        widget.middleColor ?? Theme.of(context).canvasColor;
    final T? data =
        await Navigator.of(
          context,
          rootNavigator: widget.useRootNavigator,
        ).push(
          _OpenContainerRoute<T>(
            closedColor: widget.closedColor,
            openColor: widget.openColor,
            middleColor: middleColor,
            closedShape: widget.closedShape,
            openShape: widget.openShape,
            closedBuilder: widget.closedBuilder,
            openBuilder: widget.openBuilder,
            sourceKey: _sourceKey,
            transitionDuration: widget.transitionDuration,
            transitionType: widget.transitionType,
            curve: widget.curve,
            useRootNavigator: widget.useRootNavigator,
            routeSettings: widget.routeSettings,
          ),
        );
    if (widget.onClosed != null) {
      widget.onClosed!(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Hideable(
      key: _sourceKey,
      child: GestureDetector(
        onTap: widget.tappable ? openContainer : null,
        child: Material(
          color: Colors.transparent,
          clipBehavior: widget.clipBehavior,
          shape: widget.closedShape,
          child: widget.closedBuilder(context, openContainer),
        ),
      ),
    );
  }
}

class _Hideable extends StatefulWidget {
  const _Hideable({super.key, required this.child});

  final Widget child;

  @override
  State<_Hideable> createState() => _HideableState();
}

class _HideableState extends State<_Hideable> {
  Size? get placeholderSize => _placeholderSize;
  Size? _placeholderSize;

  set placeholderSize(Size? value) {
    if (_placeholderSize == value) {
      return;
    }
    setState(() {
      _placeholderSize = value;
    });
  }

  bool get isVisible => _visible;
  bool _visible = true;

  set isVisible(bool value) {
    if (_visible == value) {
      return;
    }
    setState(() {
      _visible = value;
    });
  }

  bool get isInTree => _placeholderSize == null;

  @override
  Widget build(BuildContext context) {
    if (_placeholderSize != null) {
      return SizedBox.fromSize(size: _placeholderSize);
    }
    return Visibility(
      visible: _visible,
      maintainSize: true,
      maintainState: true,
      maintainAnimation: true,
      child: widget.child,
    );
  }
}

class _OpenContainerRoute<T> extends ModalRoute<T> with DragBackRouteMixin<T> {
  _OpenContainerRoute({
    required this.closedColor,
    required this.openColor,
    required this.middleColor,
    required this.closedBuilder,
    required ShapeBorder? closedShape,
    required this.openShape,
    required this.openBuilder,
    required this.sourceKey,
    required this.transitionDuration,
    required this.transitionType,
    required this.curve,
    required this.useRootNavigator,
    required RouteSettings? routeSettings,
  }) : _closedOpacityTween = _getClosedOpacityTween(transitionType),
       _openOpacityTween = _getOpenOpacityTween(transitionType),
       _shapeTween = ShapeBorderTween(begin: closedShape, end: openShape),
       super(settings: routeSettings);

  static _FlippableTweenSequence<Color?> _getColorTween({
    required ContainerTransitionType transitionType,
    required Color closedColor,
    required Color openColor,
    required Color middleColor,
  }) {
    switch (transitionType) {
      case ContainerTransitionType.fade:
        // 起止都透明：展开时让源行副本浮在容器里，关闭时正好收拢回该行
        return _FlippableTweenSequence<Color?>(<TweenSequenceItem<Color?>>[
          TweenSequenceItem<Color?>(
            tween: ColorTween(
              begin: closedColor.withValues(alpha: 0),
              end: closedColor,
            ),
            weight: 0.25,
          ),
          TweenSequenceItem<Color?>(
            tween: ColorTween(begin: closedColor, end: openColor),
            weight: 0.35,
          ),
          TweenSequenceItem<Color>(
            tween: ConstantTween<Color>(openColor),
            weight: 0.40,
          ),
        ]);
      case ContainerTransitionType.fadeThrough:
        return _FlippableTweenSequence<Color?>(<TweenSequenceItem<Color?>>[
          TweenSequenceItem<Color?>(
            tween: ColorTween(begin: closedColor, end: middleColor),
            weight: 1 / 5,
          ),
          TweenSequenceItem<Color?>(
            tween: ColorTween(begin: middleColor, end: openColor),
            weight: 4 / 5,
          ),
        ]);
    }
  }

  static _FlippableTweenSequence<double> _getClosedOpacityTween(
    ContainerTransitionType transitionType,
  ) {
    switch (transitionType) {
      case ContainerTransitionType.fade:
        // 行内容随容器上沿一起上移，页面盖住它之前淡出
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            weight: 0.55,
          ),
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(0.0),
            weight: 0.45,
          ),
        ]);
      case ContainerTransitionType.fadeThrough:
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            weight: 1 / 5,
          ),
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(0.0),
            weight: 4 / 5,
          ),
        ]);
    }
  }

  static _FlippableTweenSequence<double> _getOpenOpacityTween(
    ContainerTransitionType transitionType,
  ) {
    switch (transitionType) {
      case ContainerTransitionType.fade:
        // 页面随纵向拉开同步显现，撑开过程本身就是要看的动效
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(0.0),
            weight: 0.18,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            weight: 0.35,
          ),
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(1.0),
            weight: 0.47,
          ),
        ]);
      case ContainerTransitionType.fadeThrough:
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(0.0),
            weight: 1 / 5,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            weight: 4 / 5,
          ),
        ]);
    }
  }

  final Color? closedColor;
  final Color? openColor;
  final Color middleColor;
  final CloseContainerBuilder closedBuilder;
  final ShapeBorder? openShape;
  final OpenContainerBuilder<T> openBuilder;
  final GlobalKey<_HideableState> sourceKey;

  @override
  final Duration transitionDuration;
  final ContainerTransitionType transitionType;
  final Curve curve;

  final bool useRootNavigator;

  final _FlippableTweenSequence<double> _closedOpacityTween;
  final _FlippableTweenSequence<double> _openOpacityTween;
  final ShapeBorderTween _shapeTween;
  late _FlippableTweenSequence<Color?> _colorTween;
  final GlobalKey _openBuilderKey = GlobalKey();
  final RectTween _rectTween = RectTween();
  Rect? _sourceRect;

  AnimationStatus? _lastAnimationStatus;
  AnimationStatus? _currentAnimationStatus;

  @override
  TickerFuture didPush() {
    _takeMeasurements(navigatorContext: sourceKey.currentContext!);

    animation!.addStatusListener((AnimationStatus status) {
      _lastAnimationStatus = _currentAnimationStatus;
      _currentAnimationStatus = status;
      switch (status) {
        case AnimationStatus.dismissed:
          _toggleHideable(hide: false);
          break;
        case AnimationStatus.completed:
          _toggleHideable(hide: true);
          break;
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          break;
      }
    });

    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    if (isDragBackActive) {
      return super.didPop(result);
    }
    _takeMeasurements(
      navigatorContext: subtreeContext!,
      delayForSourceRoute: true,
    );
    return super.didPop(result);
  }

  @override
  void dispose() {
    if (sourceKey.currentState?.isVisible == false) {
      SchedulerBinding.instance.addPostFrameCallback(
        (Duration d) => _toggleHideable(hide: false),
      );
    }
    super.dispose();
  }

  void _toggleHideable({required bool hide}) {
    if (sourceKey.currentState != null) {
      sourceKey.currentState!
        ..placeholderSize = null
        ..isVisible = !hide;
    }
  }

  void _takeMeasurements({
    required BuildContext navigatorContext,
    bool delayForSourceRoute = false,
  }) {
    final RenderBox navigator =
        Navigator.of(
              navigatorContext,
              rootNavigator: useRootNavigator,
            ).context.findRenderObject()!
            as RenderBox;
    final Size navSize = _getSize(navigator);
    _rectTween.end = Offset.zero & navSize;

    void takeMeasurementsInSourceRoute([Duration? _]) {
      if (!navigator.attached || sourceKey.currentContext == null) {
        return;
      }
      final Rect source = _getRect(sourceKey, navigator);
      _sourceRect = source;
      sourceKey.currentState!.placeholderSize = source.size;
      // 只做纵向展开：容器从第一帧起就是整屏宽，杜绝横向 / 斜向观感
      _rectTween.begin = Rect.fromLTRB(
        0,
        source.top,
        navSize.width,
        source.bottom,
      );
    }

    if (delayForSourceRoute) {
      SchedulerBinding.instance.addPostFrameCallback(
        takeMeasurementsInSourceRoute,
      );
    } else {
      takeMeasurementsInSourceRoute();
    }
  }

  Size _getSize(RenderBox render) {
    assert(render.hasSize);
    return render.size;
  }

  Rect _getRect(GlobalKey key, RenderBox ancestor) {
    assert(key.currentContext != null);
    assert(ancestor.hasSize);
    final RenderBox render =
        key.currentContext!.findRenderObject()! as RenderBox;
    assert(render.hasSize);
    return MatrixUtils.transformRect(
      render.getTransformTo(ancestor),
      Offset.zero & render.size,
    );
  }

  bool get _transitionWasInterrupted {
    bool wasInProgress = false;
    bool isInProgress = false;

    switch (_currentAnimationStatus) {
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        isInProgress = false;
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        isInProgress = true;
        break;
      case null:
        break;
    }
    switch (_lastAnimationStatus) {
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        wasInProgress = false;
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        wasInProgress = true;
        break;
      case null:
        break;
    }
    return wasInProgress && isInProgress;
  }

  void closeContainer({T? returnValue}) {
    Navigator.of(subtreeContext!).pop(returnValue);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    _colorTween = _getColorTween(
      transitionType: transitionType,
      closedColor: closedColor ?? colorScheme.surfaceContainer,
      openColor: openColor ?? colorScheme.surface,
      middleColor: middleColor,
    );

    // Keeps the page subtree out of the per-frame rebuild.
    final Widget openChild = Builder(
      key: _openBuilderKey,
      builder: (BuildContext context) {
        return openBuilder(context, closeContainer);
      },
    );

    return Align(
      alignment: Alignment.topLeft,
      child: AnimatedBuilder(
        animation: animation,
        child: openChild,
        builder: (BuildContext context, Widget? child) {
          if (animation.isCompleted || isDragBackActive) {
            return SizedBox.expand(
              child: Material(shape: openShape, child: child),
            );
          }

          final Animation<double> curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: curve,
            reverseCurve: _transitionWasInterrupted ? null : curve.flipped,
          );
          TweenSequence<Color?>? colorTween;
          TweenSequence<double>? closedOpacityTween, openOpacityTween;
          switch (animation.status) {
            case AnimationStatus.dismissed:
            case AnimationStatus.forward:
              closedOpacityTween = _closedOpacityTween;
              openOpacityTween = _openOpacityTween;
              colorTween = _colorTween;
              break;
            case AnimationStatus.reverse:
              if (_transitionWasInterrupted) {
                closedOpacityTween = _closedOpacityTween;
                openOpacityTween = _openOpacityTween;
                colorTween = _colorTween;
                break;
              }
              closedOpacityTween = _closedOpacityTween.flipped;
              openOpacityTween = _openOpacityTween.flipped;
              colorTween = _colorTween.flipped;
              break;
            case AnimationStatus.completed:
              assert(false); // Unreachable.
              break;
          }
          assert(colorTween != null);
          assert(closedOpacityTween != null);
          assert(openOpacityTween != null);

          final Rect rect = _rectTween.evaluate(curvedAnimation)!;
          final Rect sourceRect = _sourceRect ?? _rectTween.begin ?? Rect.zero;
          final Rect endRect = _rectTween.end ?? (Offset.zero & Size.zero);

          return SizedBox.expand(
            child: Align(
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: Offset(rect.left, rect.top),
                child: SizedBox(
                  width: rect.width,
                  height: rect.height,
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    animationDuration: Duration.zero,
                    color: colorTween!.evaluate(animation),
                    shape: _shapeTween.evaluate(curvedAnimation),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: <Widget>[
                        // 源行副本：1:1 尺寸、跟着容器上沿整体上移，页面盖住它之前淡出
                        Align(
                          alignment: Alignment.topLeft,
                          child: Transform.translate(
                            offset: Offset(sourceRect.left - rect.left, 0),
                            child: SizedBox(
                              width: sourceRect.width,
                              height: sourceRect.height,
                              child:
                                  (sourceKey.currentState?.isInTree ?? false)
                                  ? null
                                  : FadeTransition(
                                      opacity: closedOpacityTween!.animate(
                                        animation,
                                      ),
                                      child: Builder(
                                        builder: (BuildContext context) {
                                          // Use dummy "open container" callback
                                          // since we are in the process of opening.
                                          return closedBuilder(context, () {});
                                        },
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        // 打开页锚定屏幕坐标：不跟着容器左上角斜着滑动，只由容器裁剪逐层露出
                        Align(
                          alignment: Alignment.topLeft,
                          child: Transform.translate(
                            offset: Offset(-rect.left, -rect.top),
                            child: SizedBox(
                              width: endRect.width,
                              height: endRect.height,
                              child: FadeTransition(
                                opacity: openOpacityTween!.animate(animation),
                                child: RepaintBoundary(child: child),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void didStartDragBack() => _toggleHideable(hide: false);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return dragBackDetector(
      isDragBackActive ? dragBackSlide(context, animation, child) : child,
    );
  }

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;
}

class _FlippableTweenSequence<T> extends TweenSequence<T> {
  _FlippableTweenSequence(this._items) : super(_items);

  final List<TweenSequenceItem<T>> _items;
  _FlippableTweenSequence<T>? _flipped;

  _FlippableTweenSequence<T>? get flipped {
    if (_flipped == null) {
      final List<TweenSequenceItem<T>> newItems = <TweenSequenceItem<T>>[];
      for (int i = 0; i < _items.length; i++) {
        newItems.add(
          TweenSequenceItem<T>(
            tween: _items[i].tween,
            weight: _items[_items.length - 1 - i].weight,
          ),
        );
      }
      _flipped = _FlippableTweenSequence<T>(newItems);
    }
    return _flipped;
  }
}
