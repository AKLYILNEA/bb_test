import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/animated_nav_icon.dart';
import 'package:bett_box/widgets/card.dart';

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
  late final AnimationController _posController = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  late final AnimationController _liftController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    value: 0.0,
  );
  late final Listenable _animListenable =
      Listenable.merge([_posController, _liftController]);

  int? _activePointerId;
  Offset? _downPosition;
  double _barWidth = 0;
  int _lastSnappedIndex = 0;
  int _lastHapticTime = 0;
  int? _animatingTargetIndex;
  late final ValueNotifier<int> _highlightedIndex =
      ValueNotifier(widget.selectedIndex);

  @override
  void initState() {
    super.initState();
    _lastSnappedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant GoogleBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        _activePointerId == null) {
      _highlightedIndex.value = widget.selectedIndex;
      if (_animatingTargetIndex != widget.selectedIndex) {
        _lastSnappedIndex = widget.selectedIndex;
        _posController.animateTo(
          widget.selectedIndex.toDouble(),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
      _animatingTargetIndex = null;
    }
  }

  @override
  void dispose() {
    _highlightedIndex.dispose();
    _posController.dispose();
    _liftController.dispose();
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

  double _calculateSlot(double dx) {
    final innerWidth = _barWidth;
    if (innerWidth <= 0 || widget.navigationItems.isEmpty) {
      return widget.selectedIndex.toDouble();
    }
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveDx = isRtl ? (innerWidth - dx) : dx;
    final count = widget.navigationItems.length;
    final slotWidth = innerWidth / count;
    final localDx = effectiveDx.clamp(0.0, innerWidth);
    final rawSlot = (localDx / slotWidth) - 0.5;
    return rawSlot.clamp(0.0, (count - 1).toDouble());
  }

  int _slotToIndex(double slot) {
    final count = widget.navigationItems.length;
    if (count == 0) return 0;
    return slot.round().clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final enableFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );
    final colorScheme = context.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final primaryColor = colorScheme.primary;
    final onSurfaceVariantColor = colorScheme.onSurfaceVariant;

    final barColor = commonCardColor(context).withValues(
      alpha: isLight ? 0.88 : 0.86,
    );
    final borderColor = isLight
        ? colorScheme.outlineVariant.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.14);

    final count = widget.navigationItems.length;
    const barHeight = 65.0;
    const baseGap = 6.0;

    final bar = LayoutBuilder(
      builder: (context, constraints) {
        _barWidth = constraints.maxWidth;
        final slotWidth = count > 0 ? _barWidth / count : _barWidth;

        return SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
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
                        sigmaX: 8.0,
                        sigmaY: 8.0,
                      ),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: barColor,
                          shape: SuperellipseBorder(
                            borderRadius: BorderRadius.circular(36),
                            side: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    if (_activePointerId != null) return;
                    _activePointerId = event.pointer;
                    _downPosition = event.localPosition;
                    final slot = _calculateSlot(event.localPosition.dx);
                    final targetIndex = _slotToIndex(slot);
                    _lastSnappedIndex = targetIndex;
                    _animatingTargetIndex = targetIndex;
                    _highlightedIndex.value = targetIndex;
                    _triggerHapticFeedback(enableFeedback);
                    _liftController.animateTo(1.0, curve: Curves.easeOut);
                    _posController.animateTo(
                      targetIndex.toDouble(),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  onPointerMove: (event) {
                    if (_activePointerId != event.pointer) return;
                    final downPos = _downPosition;
                    if (downPos != null) {
                      final delta = event.localPosition - downPos;
                      if (delta.dx.abs() > 8) {
                        final slot = _calculateSlot(event.localPosition.dx);
                        _posController.value = slot;
                        final index = _slotToIndex(slot);
                        _highlightedIndex.value = index;
                        if (index != _lastSnappedIndex) {
                          _lastSnappedIndex = index;
                          _triggerHapticFeedback(enableFeedback);
                        }
                      }
                    }
                  },
                  onPointerUp: (event) {
                    if (_activePointerId != event.pointer) return;
                    _activePointerId = null;
                    final targetIndex =
                        _slotToIndex(_calculateSlot(event.localPosition.dx));
                    _animatingTargetIndex = targetIndex;
                    _highlightedIndex.value = targetIndex;
                    _posController.animateTo(
                      targetIndex.toDouble(),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                    _liftController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                    );
                    if (targetIndex != widget.selectedIndex) {
                      widget.onTabChange(targetIndex);
                    }
                  },
                  onPointerCancel: (event) {
                    if (_activePointerId != event.pointer) return;
                    _activePointerId = null;
                    _animatingTargetIndex = null;
                    _highlightedIndex.value = widget.selectedIndex;
                    _posController.animateTo(
                      widget.selectedIndex.toDouble(),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                    _liftController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        if (count > 0)
                          AnimatedBuilder(
                            animation: _animListenable,
                            builder: (context, _) {
                              final lensPos = _posController.value;
                              final lift = _liftController.value;
                              final currentGap = baseGap * (1.0 - lift);
                              final pillWidth =
                                  math.max(0.0, slotWidth - (2 * currentGap));
                              final centerDx = (lensPos + 0.5) * slotWidth;
                              final pillStart = centerDx - (pillWidth / 2);
                              final pillTop = currentGap;
                              final pillHeight =
                                  math.max(0.0, barHeight - (2 * currentGap));
                              final pillRadius = pillHeight / 2;

                              final lensColor = primaryColor.withValues(
                                alpha: isLight
                                    ? 0.20 + (0.05 * lift)
                                    : 0.26 + (0.06 * lift),
                              );

                              return PositionedDirectional(
                                start: pillStart,
                                top: pillTop,
                                width: pillWidth,
                                height: pillHeight,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: lensColor,
                                    shape: SuperellipseBorder(
                                      borderRadius:
                                          BorderRadius.circular(pillRadius),
                                    ),
                                    shadows: [
                                      if (lift > 0.05)
                                        BoxShadow(
                                          color: (isLight
                                                  ? primaryColor
                                                  : Colors.white)
                                              .withValues(
                                            alpha: (isLight ? 0.12 : 0.08) *
                                                lift,
                                          ),
                                          blurRadius: 12,
                                          offset: Offset(0, 1 * lift),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ValueListenableBuilder<int>(
                          valueListenable: _highlightedIndex,
                          builder: (context, highlightedIndex, _) {
                            return Row(
                              children: List.generate(count, (index) {
                                final item = widget.navigationItems[index];
                                final isHighlighted = index == highlightedIndex;
                                final itemScale = isHighlighted ? 1.04 : 1.0;
                                final itemColor = isHighlighted
                                    ? primaryColor
                                    : onSurfaceVariantColor;
                                final itemFontWeight = isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w500;

                                return Expanded(
                                  child: Center(
                                    child: AnimatedScale(
                                      scale: itemScale,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      curve: Curves.easeOut,
                                      alignment: Alignment.center,
                                      child: TweenAnimationBuilder<Color?>(
                                        tween: ColorTween(
                                          begin: onSurfaceVariantColor,
                                          end: itemColor,
                                        ),
                                        duration:
                                            const Duration(milliseconds: 150),
                                        curve: Curves.easeOut,
                                        builder: (context, color, child) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedNavIcon(
                                                label: item.label,
                                                selected: isHighlighted,
                                                color: color ??
                                                    onSurfaceVariantColor,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.label.localizedName,
                                                style: TextStyle(
                                                  fontSize: 11.0,
                                                  fontWeight: itemFontWeight,
                                                  color: color,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
