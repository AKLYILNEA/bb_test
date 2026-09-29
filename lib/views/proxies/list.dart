import 'dart:async';
import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'card.dart';
import 'common.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

const _listRevealDuration = Duration(milliseconds: 240);

class ProxiesListView extends ConsumerWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proxiesListStateProvider);

    if (state.groups.isEmpty) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
        illustration: NullStatusIllustration.proxies,
      );
    }

    return _ProxyGroupsList(
      groups: state.groups,
      columns: state.columns,
      cardType: state.proxyCardType,
      sortType: state.proxiesSortType,
      sortNum: state.sortNum,
      currentUnfoldSet: state.currentUnfoldSet,
    );
  }
}

class _ProxyGroupsList extends ConsumerStatefulWidget {
  final List<Group> groups;
  final int columns;
  final ProxyCardType cardType;
  final ProxiesSortType sortType;
  final num sortNum;
  final Set<String> currentUnfoldSet;

  const _ProxyGroupsList({
    required this.groups,
    required this.columns,
    required this.cardType,
    required this.sortType,
    required this.sortNum,
    required this.currentUnfoldSet,
  });

  @override
  ConsumerState<_ProxyGroupsList> createState() => _ProxyGroupsListState();
}

class _ProxyGroupsListState extends ConsumerState<_ProxyGroupsList> {
  final ScrollController _scrollController = ScrollController();
  GroupOffsets _groupOffsets = GroupOffsets.empty;
  double _containerHeight = 0;
  String? _enterGroupName;
  Timer? _enterTimer;
  Timer? _revealScrollTimer;
  final Set<String> _collapsingGroups = <String>{};

  @override
  void dispose() {
    _enterTimer?.cancel();
    _revealScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startEnterAnimated(String groupName) {
    _enterTimer?.cancel();
    _enterGroupName = groupName;
    _enterTimer = Timer(_listRevealDuration, () {
      if (mounted) {
        setState(() {
          _enterGroupName = null;
        });
      }
    });
  }

  void _scheduleRevealScroll(String groupName) {
    _revealScrollTimer?.cancel();
    _revealScrollTimer = Timer(_listRevealDuration, () {
      if (!mounted) return;
      _autoScrollToGroup(groupName);
    });
  }

  void _handleToggle(String groupName) {
    final tempUnfoldSet = Set<String>.from(widget.currentUnfoldSet);
    final isExpanding = !tempUnfoldSet.contains(groupName);
    if (isExpanding) {
      tempUnfoldSet.add(groupName);
      _startEnterAnimated(groupName);
      _scheduleRevealScroll(groupName);
      if (_collapsingGroups.remove(groupName)) {
        setState(() {});
      }
    } else {
      tempUnfoldSet.remove(groupName);
      _enterTimer?.cancel();
      _revealScrollTimer?.cancel();
      _enterGroupName = null;
      setState(() {
        _collapsingGroups.add(groupName);
      });
    }
    globalState.appController.updateCurrentUnfoldSet(tempUnfoldSet);
  }

  GroupOffsets _getGroupOffsets({
    required List<Group> groups,
    required int columns,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
  }) {
    final offsets = <double>[];
    final rowExtent = getItemHeight(cardType) + 8.0;
    const headerExtent = 72.0;
    var currentOffset = 16.0;
    for (final group in groups) {
      offsets.add(currentOffset);
      currentOffset += headerExtent;
      if (currentUnfoldSet.contains(group.name)) {
        final rowCount = (group.all.length + columns - 1) ~/ columns;
        currentOffset += rowCount * rowExtent;
      }
    }
    return GroupOffsets(groups, offsets);
  }

  void _animateToOffset(double targetOffset) {
    if (!mounted || !_scrollController.hasClients) return;
    final currentOffset = _scrollController.offset;
    final clampedTarget = targetOffset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    final distance = (clampedTarget - currentOffset).abs();
    if (distance < 1.0) return;

    final durationMs = (240 + (distance * 0.1)).clamp(280, 400).toInt();
    _scrollController.animateTo(
      clampedTarget,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 16.0,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start - padding;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start - padding;
      }
    }

    _animateToOffset(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    if (!_scrollController.hasClients || _containerHeight <= 0) return;
    final pixels = _scrollController.position.pixels;
    final offset = _groupOffsets.offsetOf(groupName);
    const headerExtent = 72.0;
    _scrollToMakeVisibleWithPadding(
      containerHeight: _containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + headerExtent,
      padding: 16.0,
    );
  }

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

    if (_enterGroupName != null) {
      _enterTimer?.cancel();
      _enterGroupName = null;
    }

    final group = widget.groups.getGroup(groupName);
    if (group == null) return;

    final sortedProxies = globalState.appController.getSortProxies(
      proxies: group.all,
      sortType: widget.sortType,
      testUrl: group.testUrl,
    );
    final proxyIndex = sortedProxies.indexWhere((p) => p.name == selectedName);
    if (proxyIndex < 0) return;

    final groupOffset = _groupOffsets.offsetOf(groupName);
    const headerExtent = 72.0;
    final rowExtent = getItemHeight(widget.cardType) + 8.0;
    final rowIndex = proxyIndex ~/ widget.columns;

    final nodeTop = groupOffset + headerExtent + rowIndex * rowExtent;
    final nodeBottom = nodeTop + rowExtent;

    final containerHeight = _containerHeight > 0
        ? _containerHeight
        : MediaQuery.sizeOf(context).height;

    final totalSpan = (nodeBottom + 8.0) - (groupOffset - 16.0);
    double targetOffset;
    if (totalSpan <= containerHeight) {
      targetOffset = groupOffset - 16.0;
    } else {
      targetOffset = (nodeTop - rowExtent - 16.0).clamp(
        groupOffset - 16.0,
        double.infinity,
      );
    }

    _animateToOffset(targetOffset);
  }

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required bool isExpand,
    required bool enterAnimated,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final isCollapsing = _collapsingGroups.contains(group.name);
    final showList = isExpand || isCollapsing;
    final sortedProxies = showList
        ? globalState.appController.getSortProxies(
            proxies: group.all,
            sortType: widget.sortType,
            testUrl: group.testUrl,
          )
        : const <Proxy>[];

    final rows = <List<Proxy>>[];
    if (showList) {
      for (var i = 0; i < sortedProxies.length; i += columns) {
        final end = (i + columns < sortedProxies.length)
            ? i + columns
            : sortedProxies.length;
        rows.add(sortedProxies.sublist(i, end));
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: SizedBox(
              height: 64.0,
              child: _GroupHeader(
                key: ValueKey('header_${group.name}'),
                group: group,
                isExpand: isExpand,
                enterAnimated: enterAnimated,
                onToggle: () => _handleToggle(group.name),
                cardType: cardType,
                columns: columns,
                onScrollToSelected: () => _scrollToSelected(group.name),
              ),
            ),
          ),
        ),
        if (showList)
          _GroupProxyListSliver(
            key: ValueKey('expanded_group_${group.name}'),
            group: group,
            rows: rows,
            columns: columns,
            cardType: cardType,
            enterAnimated: enterAnimated,
            collapseRequested: isCollapsing,
            onCollapsed: () {
              if (!mounted) return;
              setState(() {
                _collapsingGroups.remove(group.name);
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        _containerHeight = max(constraints.maxHeight, 0);
        _groupOffsets = _getGroupOffsets(
          groups: widget.groups,
          columns: widget.columns,
          currentUnfoldSet: widget.currentUnfoldSet,
          cardType: widget.cardType,
        );

        return CommonScrollBar(
          controller: _scrollController,
          feather: true,
          child: CustomScrollView(
            key: const PageStorageKey<String>('proxies_list'),
            controller: _scrollController,
            cacheExtent: 500.0,
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
              for (final group in widget.groups)
                _buildGroup(
                  context,
                  group: group,
                  isExpand: widget.currentUnfoldSet.contains(group.name),
                  enterAnimated: _enterGroupName == group.name,
                  columns: widget.columns,
                  cardType: widget.cardType,
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: (globalState.isAndroidTV ? 48.0 : 16.0) +
                      (isMobileView
                          ? getFloatingBottomBarReserveHeight(context)
                          : 0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupProxyListSliver extends StatefulWidget {
  final Group group;
  final List<List<Proxy>> rows;
  final int columns;
  final ProxyCardType cardType;
  final bool enterAnimated;
  final bool collapseRequested;
  final VoidCallback? onCollapsed;

  const _GroupProxyListSliver({
    super.key,
    required this.group,
    required this.rows,
    required this.columns,
    required this.cardType,
    this.enterAnimated = true,
    this.collapseRequested = false,
    this.onCollapsed,
  });

  @override
  State<_GroupProxyListSliver> createState() => _GroupProxyListSliverState();
}

class _GroupProxyListSliverState extends State<_GroupProxyListSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  late SliverChildBuilderDelegate _delegate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _listRevealDuration,
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic.flipped,
    );
    _controller.addStatusListener(_handleStatus);
    _delegate = _buildDelegate();
    if (widget.enterAnimated) {
      _controller.value = 1;
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant _GroupProxyListSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapseRequested && !oldWidget.collapseRequested) {
      _controller.forward();
    } else if (!widget.collapseRequested && oldWidget.collapseRequested) {
      _controller
        ..stop()
        ..value = 0;
    }
    if (widget.rows.length != oldWidget.rows.length ||
        widget.columns != oldWidget.columns ||
        widget.cardType != oldWidget.cardType) {
      _delegate = _buildDelegate();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && widget.collapseRequested) {
      widget.onCollapsed?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SliverChildBuilderDelegate _buildDelegate() {
    return SliverChildBuilderDelegate(
      (context, index) => _buildProxyRow(context, index),
      childCount: widget.rows.length,
    );
  }

  Widget _buildProxyRow(BuildContext context, int rowIndex) {
    final proxies = widget.rows[rowIndex];
    final groupName = widget.group.name;
    final cardWidgets = <Widget>[];

    for (var i = 0; i < widget.columns; i++) {
      if (i < proxies.length) {
        final proxy = proxies[i];
        cardWidgets.add(
          Expanded(
            child: ProxyCard(
              key: ValueKey('$groupName.${proxy.name}'),
              proxy: proxy,
              groupName: groupName,
              type: widget.cardType,
              groupType: widget.group.type,
              testUrl: widget.group.testUrl,
            ),
          ),
        );
      } else {
        cardWidgets.add(const Expanded(child: SizedBox()));
      }
    }

    final rowChildren = <Widget>[];
    for (var i = 0; i < cardWidgets.length; i++) {
      rowChildren.add(cardWidgets[i]);
      if (i < cardWidgets.length - 1) {
        rowChildren.add(const SizedBox(width: 8));
      }
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: SizedBox(
          height: getItemHeight(widget.cardType),
          child: Row(children: rowChildren),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final factor = 1 - _reveal.value;
        return _AnimatedExtentSliver(
          factor: factor,
          surfaceColor: context.colorScheme.surface,
          child: SliverFixedExtentList(
            itemExtent: getItemHeight(widget.cardType) + 8.0,
            delegate: _delegate,
          ),
        );
      },
    );
  }
}

class _AnimatedExtentSliver extends SingleChildRenderObjectWidget {
  final double factor;
  final Color surfaceColor;

  const _AnimatedExtentSliver({
    required super.child,
    required this.factor,
    required this.surfaceColor,
  });

  @override
  _RenderAnimatedExtentSliver createRenderObject(BuildContext context) {
    return _RenderAnimatedExtentSliver(factor, surfaceColor);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnimatedExtentSliver renderObject,
  ) {
    renderObject
      ..factor = factor
      ..surfaceColor = surfaceColor;
  }
}

class _RenderAnimatedExtentSliver extends RenderProxySliver {
  _RenderAnimatedExtentSliver(this._factor, this._surfaceColor);

  static const _edgeGap = 8.0;
  static const _featherExtent = 28.0;

  double _factor;
  Color _surfaceColor;

  double get factor => _factor;

  set factor(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_factor == next) return;
    _factor = next;
    markNeedsLayout();
    markNeedsPaint();
  }

  Color get surfaceColor => _surfaceColor;

  set surfaceColor(Color value) {
    if (_surfaceColor == value) return;
    _surfaceColor = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final childGeometry = child.geometry ?? SliverGeometry.zero;
    final factor = _factor;
    final maxPaintExtent = childGeometry.maxPaintExtent * factor;
    final scrollExtent = childGeometry.scrollExtent * factor;
    final paintExtent = max(
      0.0,
      min(childGeometry.paintExtent, maxPaintExtent - constraints.scrollOffset),
    );
    final layoutExtent = max(
      0.0,
      min(childGeometry.layoutExtent, childGeometry.paintOrigin + paintExtent),
    );
    final hitTestExtent = max(
      0.0,
      min(childGeometry.hitTestExtent, childGeometry.paintOrigin + paintExtent),
    );
    geometry = SliverGeometry(
      paintOrigin: childGeometry.paintOrigin,
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      layoutExtent: layoutExtent,
      maxPaintExtent: maxPaintExtent,
      cacheExtent: childGeometry.cacheExtent,
      maxScrollObstructionExtent: childGeometry.maxScrollObstructionExtent,
      visible: childGeometry.visible,
      hitTestExtent: hitTestExtent,
      hasVisualOverflow: childGeometry.hasVisualOverflow || factor < 1.0,
      scrollOffsetCorrection: childGeometry.scrollOffsetCorrection,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final paintExtent = geometry?.paintExtent ?? 0.0;
    final coreExtent = max(paintExtent - _edgeGap, 0.0);
    if (coreExtent <= 0) {
      layer = null;
      return;
    }
    final crossExtent = constraints.crossAxisExtent;
    final isVertical = constraints.axis == Axis.vertical;
    final coreSize = isVertical
        ? Size(crossExtent, coreExtent)
        : Size(coreExtent, crossExtent);
    final hidden = (1 - _factor).clamp(0.0, 1.0);
    if (coreExtent < paintExtent || hidden > 0) {
      layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & coreSize,
        (context, offset) => super.paint(context, offset),
        oldLayer: layer as ClipRectLayer?,
      );
    } else {
      layer = null;
      super.paint(context, offset);
    }
    if (hidden <= 0) return;
    final canvas = context.canvas;
    final coreRect = (Offset.zero & coreSize).shift(offset);
    canvas.drawRect(
      coreRect,
      Paint()..color = _surfaceColor.withValues(alpha: hidden),
    );
    final featherExtent = min(_featherExtent, coreExtent);
    if (featherExtent > 0) {
      final featherRect = isVertical
          ? Rect.fromLTWH(
              0,
              coreExtent - featherExtent,
              crossExtent,
              featherExtent,
            ).shift(offset)
          : Rect.fromLTWH(
              coreExtent - featherExtent,
              0,
              featherExtent,
              crossExtent,
            ).shift(offset);
      final shader = LinearGradient(
        begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
        end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [
          _surfaceColor.withValues(alpha: 0),
          _surfaceColor.withValues(alpha: hidden),
        ],
      ).createShader(featherRect);
      canvas.drawRect(featherRect, Paint()..shader = shader);
    }
  }
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final bool enterAnimated;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    this.enterAnimated = false,
    required this.onToggle,
    required this.cardType,
    required this.columns,
    this.onScrollToSelected,
  });

  static final _circleButtonStyle = IconButton.styleFrom(
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.all(2),
    fixedSize: const Size(32, 32),
    minimumSize: const Size(32, 32),
  );

  static final _circleFilledTonalStyle = IconButton.styleFrom(
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.all(2),
    fixedSize: const Size(32, 32),
    minimumSize: const Size(32, 32),
  );

  Widget _buildActionScale({
    required Widget child,
    required String key,
  }) {
    if (!enterAnimated) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(key),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      builder: (_, scale, c) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: c,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((s) => s.iconStyle),
    );
    final icon = ref.watch(proxyIconProvider(group.name));
    final nameEmoji = getFirstEmoji(group.name);
    final useEmojiIcon =
        iconStyle != ProxiesIconStyle.none &&
        icon.isEmpty &&
        nameEmoji.isNotEmpty;
    final selectedProxyName = ref
        .watch(getSelectedProxyNameProvider(group.name))
        .getSafeValue('');

    final selectedProxyIcon = ref.watch(
      proxyIconProvider(selectedProxyName),
    );

    return CommonCard(
      radius: 20,
      type: CommonCardType.filled,
      onPressed: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildIcon(
              context,
              iconStyle,
              icon,
              emoji: useEmojiIcon ? nameEmoji : '',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiText(
                    useEmojiIcon ? removeLeadingEmoji(group.name) : group.name,
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        group.type.name,
                        style: context.textTheme.labelMedium?.toLight,
                      ),
                      if (selectedProxyName.isNotEmpty) ...[
                        Text(
                          '  •  ',
                          style: context.textTheme.labelMedium?.toLight,
                        ),
                        if (selectedProxyIcon.isNotEmpty) ...[
                          CommonTargetIcon(
                            src: selectedProxyIcon,
                            size: globalState.measure.labelMediumHeight,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: EmojiText(
                            selectedProxyName,
                            style: context.textTheme.labelMedium?.toLight,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isExpand) ...[
              _buildActionScale(
                key: 'locate_${group.name}',
                child: IconButton(
                  key: ValueKey('locate_${group.name}'),
                  style: _circleButtonStyle,
                  iconSize: 19,
                  icon: const Icon(FluentIcons.target_arrow_24_regular),
                  onPressed: onScrollToSelected,
                  tooltip: appLocalizations.locate,
                ),
              ),
              const SizedBox(width: 2),
              _buildActionScale(
                key: 'delay_${group.name}',
                child: AnimatedBuilder(
                  key: ValueKey('delay_test_${group.name}'),
                  animation: delayTestCoordinator,
                  builder: (_, _) {
                    final isTestingThisGroup = delayTestCoordinator
                        .isTestingGroup(group.name);
                    return IconButton(
                      style: _circleButtonStyle,
                      iconSize: 20,
                      icon: isTestingThisGroup
                          ? SizedBox.square(
                              dimension: 18,
                              child: SpinKitFadingCircle(
                                color: context.colorScheme.primary,
                                size: 18,
                              ),
                            )
                          : const Icon(FluentIcons.top_speed_24_regular),
                      onPressed: delayTestCoordinator.isTesting
                          ? null
                          : () => _delayTest(context),
                      tooltip: appLocalizations.startTest,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton.filledTonal(
              key: ValueKey('expand_${group.name}'),
              style: _circleFilledTonalStyle,
              iconSize: 24,
              icon: CommonExpandIcon(expand: isExpand),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiIcon(String emoji, double size) {
    return EmojiText(
      emoji,
      style: TextStyle(fontSize: size * 0.75, height: 1.2),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    ProxiesIconStyle style,
    String icon, {
    String emoji = '',
  }) {
    if (style == ProxiesIconStyle.none) return const SizedBox();
    const iconSize = 40.0;
    if (style == ProxiesIconStyle.standard) {
      return Container(
        margin: const EdgeInsets.only(right: 16),
        width: iconSize,
        height: iconSize,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: context.colorScheme.secondaryContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: emoji.isNotEmpty
            ? _buildEmojiIcon(emoji, iconSize - 12)
            : CommonTargetIcon(src: icon, size: iconSize - 12),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: iconSize,
      height: iconSize,
      alignment: Alignment.center,
      child: emoji.isNotEmpty
          ? _buildEmojiIcon(emoji, iconSize - 8)
          : CommonTargetIcon(src: icon, size: iconSize - 8),
    );
  }

  Future<void> _delayTest(BuildContext context) async {
    await delayTest(group.all, testUrl: group.testUrl, groupName: group.name);
  }
}
