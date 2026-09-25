import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/widgets/animated_nav_icon.dart';
import 'package:bett_box/widgets/sidebar_toggle_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _compactWidth = 48.0;
const _itemSize = 40.0;
const _itemGap = 4.0;
const _toggleGap = 8.0;
const _verticalInset = 4.0;
const _maxSideInset = 12.0;
const _iconSize = 24.0;
const _labelGap = 12.0;
const _indicatorWidth = 3.0;
const _indicatorHeight = 16.0;
const _expandDuration = Duration(milliseconds: 250);
const _indicatorDuration = Duration(milliseconds: 320);

final _itemShape = const RoundedSuperellipseBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
);

class NavigationSidebar extends StatefulWidget {
  const NavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
    this.onToggle,
    this.windowControls = Size.zero,
  });

  final List<NavigationItem> destinations;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;
  final VoidCallback? onToggle;
  final Size windowControls;

  @override
  State<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar>
    with SingleTickerProviderStateMixin {
  final _overlayController = OverlayPortalController();
  late final AnimationController _overlayExpansion = AnimationController(
    vsync: this,
    duration: _expandDuration,
  );
  late final CurvedAnimation _overlayProgress = CurvedAnimation(
    parent: _overlayExpansion,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didUpdateWidget(covariant NavigationSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onToggle != null && _overlayController.isShowing) {
      _overlayExpansion.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hideIfDismissed());
    }
  }

  void _handleToggle() {
    final onToggle = widget.onToggle;
    if (onToggle != null) {
      onToggle();
    } else if (_overlayExpansion.isForwardOrCompleted) {
      _closeOverlay();
    } else {
      _overlayController.show();
      _overlayExpansion.forward();
    }
  }

  void _closeOverlay() {
    _overlayExpansion.reverse().whenCompleteOrCancel(_hideIfDismissed);
  }

  void _hideIfDismissed() {
    if (mounted && _overlayExpansion.isDismissed) {
      _overlayController.hide();
    }
  }

  @override
  void dispose() {
    _overlayProgress.dispose();
    _overlayExpansion.dispose();
    super.dispose();
  }

  double _calculateExpandedWidth(BuildContext context) {
    final labelStyle =
        context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    double maxTextWidth = 0.0;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    for (final item in widget.destinations) {
      final text = item.label.localizedName;
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      if (textPainter.width > maxTextWidth) {
        maxTextWidth = textPainter.width;
      }
    }

    final total = 4.0 + 8.0 + 24.0 + 12.0 + maxTextWidth + 12.0 + 4.0 + 16.0;
    return math.max(140.0, math.min(240.0, total.ceilToDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final expandedWidth = _calculateExpandedWidth(context);

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayChildBuilder: (context, info) {
        return _SidebarOverlay(
          anchor: MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          ),
          overlayWidth: info.overlaySize.width,
          progress: _overlayProgress,
          onDismiss: _closeOverlay,
          builder: (progress) => Padding(
            padding: safePadding,
            child: _SidebarPane(
              progress: progress,
              windowControls: widget.windowControls,
              expandedWidth: expandedWidth,
              expanded: true,
              destinations: widget.destinations,
              selectedIndex: widget.selectedIndex,
              onSelected: (index) {
                widget.onSelected(index);
                _closeOverlay();
              },
              onToggle: _closeOverlay,
            ),
          ),
        );
      },
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.expanded ? 1.0 : 0.0),
          duration: _expandDuration,
          curve: Curves.easeInOutCubic,
          builder: (context, progress, _) => _SidebarPane(
            progress: progress,
            windowControls: widget.windowControls,
            expandedWidth: expandedWidth,
            expanded: widget.expanded,
            destinations: widget.destinations,
            selectedIndex: widget.selectedIndex,
            onSelected: widget.onSelected,
            onToggle: _handleToggle,
          ),
        ),
      ),
    );
  }
}

class _SidebarOverlay extends StatelessWidget {
  const _SidebarOverlay({
    required this.anchor,
    required this.overlayWidth,
    required this.progress,
    required this.onDismiss,
    required this.builder,
  });

  final Rect anchor;
  final double overlayWidth;
  final Animation<double> progress;
  final VoidCallback onDismiss;
  final Widget Function(double progress) builder;

  @override
  Widget build(BuildContext context) {
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    final colorScheme = context.colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: isLtr ? anchor.left : null,
          right: isLtr ? null : overlayWidth - anchor.right,
          top: anchor.top,
          height: anchor.height,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            },
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    onDismiss();
                    return null;
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: Material(
                  color: colorScheme.surfaceContainer,
                  shape: BorderDirectional(
                    end: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (_, _) => builder(progress.value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarColors {
  _SidebarColors(ColorScheme scheme)
    : selectedFill = scheme.onSurface.withValues(alpha: 0.08),
      label = scheme.onSurface,
      icon = scheme.onSurfaceVariant,
      indicator = scheme.primary,
      overlay = WidgetStateProperty.fromMap({
        WidgetState.pressed: scheme.onSurface.withValues(alpha: 0.06),
        WidgetState.focused: scheme.onSurface.withValues(alpha: 0.1),
        WidgetState.hovered: scheme.onSurface.withValues(alpha: 0.04),
        WidgetState.any: Colors.transparent,
      });

  final Color selectedFill;
  final Color label;
  final Color icon;
  final Color indicator;
  final WidgetStateProperty<Color> overlay;
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane({
    required this.progress,
    required this.windowControls,
    required this.expandedWidth,
    required this.expanded,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onToggle,
  });

  final double progress;
  final Size windowControls;
  final double expandedWidth;
  final bool expanded;
  final List<NavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = _SidebarColors(context.colorScheme);
    final fontSize = context.textTheme.bodyMedium?.fontSize ?? 14;
    final labelOpacity = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    final compactWidth = math.max(_compactWidth, windowControls.width);
    final sideInset = math.min(_maxSideInset, (compactWidth - _itemSize) / 2);
    final itemWidth = compactWidth - sideInset * 2;
    final iconInset = (itemWidth - _iconSize) / 2;
    final itemHeight =
        _itemSize + MediaQuery.textScalerOf(context).scale(fontSize) - fontSize;
    final rowWidth = expandedWidth - sideInset * 2;
    final labelStyle = context.textTheme.bodyMedium?.copyWith(
      color: colors.label,
    );

    return SizedBox(
      width: lerpDouble(compactWidth, expandedWidth, progress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: windowControls.height + _verticalInset),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SidebarButton(
              colors: colors,
              height: itemHeight,
              sideInset: sideInset,
              tooltip: appLocalizations.toggleLabel,
              tooltipIsLabel: true,
              onTap: onToggle,
              child: SizedBox(
                width: itemWidth,
                child: Center(
                  child: SidebarToggleIcon(
                    progress: progress,
                    size: _iconSize,
                    color: colors.icon,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _toggleGap),
          Expanded(
            child: ScrollConfiguration(
              behavior: const HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, item) in destinations.indexed)
                          _SidebarButton(
                            key: ValueKey(item.label),
                            colors: colors,
                            height: itemHeight,
                            sideInset: sideInset,
                            selected: index == selectedIndex,
                            tooltip: item.label.localizedName,
                            onTap: () => onSelected(index),
                            child: _DestinationRow(
                              item: item,
                              selected: index == selectedIndex,
                              width: rowWidth,
                              iconInset: iconInset,
                              style: labelStyle,
                              labelOpacity: labelOpacity,
                            ),
                          ),
                      ],
                    ),
                    if (selectedIndex < destinations.length)
                      _SelectionIndicator(
                        color: colors.indicator,
                        index: selectedIndex,
                        start: sideInset,
                        stride: itemHeight + _itemGap,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _verticalInset),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    super.key,
    required this.colors,
    required this.height,
    required this.sideInset,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected,
    this.tooltipIsLabel = false,
  });

  final _SidebarColors colors;
  final double height;
  final double sideInset;
  final bool? selected;
  final String tooltip;
  final bool tooltipIsLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sideInset,
        vertical: _itemGap / 2,
      ),
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        child: Material(
          color: selected == true ? colors.selectedFill : Colors.transparent,
          shape: _itemShape,
          child: InkWell(
            onTap: onTap,
            customBorder: _itemShape,
            mouseCursor: SystemMouseCursors.click,
            splashFactory: NoSplash.splashFactory,
            overlayColor: colors.overlay,
            child: Tooltip(
              message: tooltip,
              excludeFromSemantics: !tooltipIsLabel,
              child: IconTheme.merge(
                data: IconThemeData(size: _iconSize, color: colors.icon),
                child: SizedBox(height: height, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.item,
    required this.selected,
    required this.width,
    required this.iconInset,
    required this.style,
    required this.labelOpacity,
  });

  final NavigationItem item;
  final bool selected;
  final double width;
  final double iconInset;
  final TextStyle? style;
  final double labelOpacity;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style?.copyWith(
      color: selected ? context.colorScheme.primary : style?.color,
      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
    );

    return ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: width,
        maxWidth: width,
        child: Row(
          children: [
            SizedBox(width: iconInset),
            AnimatedNavIcon(
              label: item.label,
              selected: selected,
              color: selected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: _labelGap),
            Expanded(
              child: Opacity(
                opacity: labelOpacity,
                alwaysIncludeSemantics: true,
                child: Text(
                  item.label.localizedName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveStyle,
                ),
              ),
            ),
            const SizedBox(width: _labelGap),
          ],
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatefulWidget {
  const _SelectionIndicator({
    required this.color,
    required this.index,
    required this.start,
    required this.stride,
  });

  final Color color;
  final int index;
  final double start;
  final double stride;

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _indicatorDuration,
    value: 1,
  );
  late int _from = widget.index;

  @override
  void didUpdateWidget(covariant _SelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _topOf(int index) =>
      index * widget.stride + (widget.stride - _indicatorHeight) / 2;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final from = _topOf(_from);
        final to = _topOf(widget.index);
        final lead = Curves.easeOutCubic.transform(math.min(1, t / 0.6));
        final trail = Curves.easeInOutCubic.transform(
          math.max(0, (t - 0.35) / 0.65),
        );
        final (top, bottom) = to >= from
            ? (lerpDouble(from, to, trail)!, lerpDouble(from, to, lead)!)
            : (lerpDouble(from, to, lead)!, lerpDouble(from, to, trail)!);
        return PositionedDirectional(
          start: widget.start,
          top: top,
          width: _indicatorWidth,
          height: bottom - top + _indicatorHeight,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: widget.color,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}
