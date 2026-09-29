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

const _listRevealMinDuration = Duration(milliseconds: 166);
const _listRevealMaxDuration = Duration(milliseconds: 286);
const _listRevealSpeed = 0.551;
const _listFadeFraction = 0.55;

Duration listRevealDuration(double contentExtent) {
  final milliseconds = ((180 + contentExtent * 0.35) * _listRevealSpeed)
      .clamp(
        _listRevealMinDuration.inMilliseconds.toDouble(),
        _listRevealMaxDuration.inMilliseconds.toDouble(),
      )
      .round();
  return Duration(milliseconds: milliseconds);
}

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
  final Set<String> _enterGroups = <String>{};
  final Set<String> _collapsingGroups = <String>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleToggle(String groupName) {
    final tempUnfoldSet = Set<String>.from(widget.currentUnfoldSet);
    final isExpanding = !tempUnfoldSet.contains(groupName);
    if (isExpanding) {
      tempUnfoldSet.add(groupName);
      _enterGroups.add(groupName);
      if (_collapsingGroups.remove(groupName)) {
        setState(() {});
      }
    } else {
      tempUnfoldSet.remove(groupName);
      _enterGroups.remove(groupName);
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

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

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

  final Map<String, _GroupRows> _rowsCache = <String, _GroupRows>{};

  List<List<Proxy>> _rowsOf({
    required Group group,
    required int columns,
  }) {
    final input = group.all;
    final sortType = widget.sortType;
    final testUrl = group.testUrl;
    final sortNum = widget.sortNum;
    final cached = _rowsCache[group.name];
    if (cached != null &&
        cached.columns == columns &&
        cached.sortType == sortType &&
        cached.testUrl == testUrl &&
        cached.sortNum == sortNum &&
        _sameProxies(cached.input, input)) {
      return cached.rows;
    }
    final sorted = globalState.appController.getSortProxies(
      proxies: input,
      sortType: sortType,
      testUrl: testUrl,
    );
    final rows = <List<Proxy>>[];
    for (var i = 0; i < sorted.length; i += columns) {
      final end = i + columns < sorted.length ? i + columns : sorted.length;
      rows.add(sorted.sublist(i, end));
    }
    _rowsCache[group.name] = _GroupRows(
      input: input,
      sortType: sortType,
      testUrl: testUrl,
      columns: columns,
      sortNum: sortNum,
      rows: rows,
    );
    return rows;
  }

  bool _sameProxies(List<Proxy> a, List<Proxy> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required bool isExpand,
    required bool enterAnimated,
    required bool isLast,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final isCollapsing = _collapsingGroups.contains(group.name);
    final showList = isExpand || isCollapsing;
    final rows = showList
        ? _rowsOf(group: group, columns: columns)
        : const <List<Proxy>>[];

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
                collapsing: isCollapsing,
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
            revealSpace: !isLast,
            clipContent: !isLast,
            collapseRequested: isCollapsing,
            onCollapsed: () {
              if (!mounted) return;
              setState(() {
                _collapsingGroups.remove(group.name);
              });
            },
            onEntered: () {
              if (!mounted) return;
              setState(() {
                _enterGroups.remove(group.name);
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
            cacheExtent: 250.0,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              for (var i = 0; i < widget.groups.length; i++)
                _buildGroup(
                  context,
                  group: widget.groups[i],
                  isExpand: widget.currentUnfoldSet.contains(
                    widget.groups[i].name,
                  ),
                    enterAnimated: _enterGroups.contains(widget.groups[i].name),
                    isLast: i == widget.groups.length - 1,
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
  final bool revealSpace;
  final bool clipContent;
  final bool collapseRequested;
  final VoidCallback? onCollapsed;
  final VoidCallback? onEntered;

  const _GroupProxyListSliver({
    super.key,
    required this.group,
    required this.rows,
    required this.columns,
    required this.cardType,
    this.enterAnimated = true,
    this.revealSpace = true,
    this.clipContent = true,
    this.collapseRequested = false,
    this.onCollapsed,
    this.onEntered,
  });

  @override
  State<_GroupProxyListSliver> createState() => _GroupProxyListSliverState();
}

class _GroupProxyListSliverState extends State<_GroupProxyListSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  late Widget _list;

  @override
  void initState() {
    super.initState();
    final extent = widget.rows.length * (getItemHeight(widget.cardType) + 8.0);
    _controller = AnimationController(
      vsync: this,
      duration: listRevealDuration(extent),
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic.flipped,
    );
    _controller.addStatusListener(_handleStatus);
    _syncList();
    if (widget.enterAnimated) {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.collapseRequested) return;
        _controller.reverse();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _GroupProxyListSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapseRequested && !oldWidget.collapseRequested) {
      _controller.forward();
    } else if (!widget.collapseRequested && oldWidget.collapseRequested) {
      if (_controller.value > 0) {
        _controller.reverse();
      } else {
        _controller.stop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onEntered?.call();
        });
      }
    }
    if (!_sameRows(widget.rows, oldWidget.rows) ||
        widget.columns != oldWidget.columns ||
        widget.cardType != oldWidget.cardType ||
        widget.group.type != oldWidget.group.type ||
        widget.group.testUrl != oldWidget.group.testUrl) {
      _syncList();
    }
  }

  bool _sameRows(List<List<Proxy>> a, List<List<Proxy>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final rowA = a[i];
      final rowB = b[i];
      if (rowA.length != rowB.length) return false;
      for (var j = 0; j < rowA.length; j++) {
        if (!identical(rowA[j], rowB[j])) return false;
      }
    }
    return true;
  }

  void _handleStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && widget.collapseRequested) {
      widget.onCollapsed?.call();
    } else if (status == AnimationStatus.dismissed && widget.enterAnimated) {
      widget.onEntered?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncList() {
    _list = SliverFixedExtentList(
      itemExtent: getItemHeight(widget.cardType) + 8.0,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildProxyRow(context, index),
        childCount: widget.rows.length,
        addAutomaticKeepAlives: false,
      ),
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

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: SizedBox(
        height: getItemHeight(widget.cardType),
        child: Row(children: rowChildren),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: _list,
      builder: (context, list) {
        final collapsing = widget.collapseRequested;
        final progress = collapsing
            ? _controller.value
            : 1 - _controller.value;
        final fade = (progress / _listFadeFraction).clamp(0.0, 1.0);
        final animateSpace = widget.revealSpace || collapsing;
        return _AnimatedExtentSliver(
          factor: animateSpace ? 1 - _reveal.value : 1.0,
          hidden: collapsing ? fade : 1 - fade,
          clipContent: widget.clipContent,
          surfaceColor: context.colorScheme.surface,
          child: list!,
        );
      },
    );
  }
}

class _AnimatedExtentSliver extends SingleChildRenderObjectWidget {
  final double factor;
  final double hidden;
  final bool clipContent;
  final Color surfaceColor;

  const _AnimatedExtentSliver({
    required super.child,
    required this.factor,
    required this.hidden,
    required this.clipContent,
    required this.surfaceColor,
  });

  @override
  _RenderAnimatedExtentSliver createRenderObject(BuildContext context) {
    return _RenderAnimatedExtentSliver(
      factor,
      hidden,
      clipContent,
      surfaceColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnimatedExtentSliver renderObject,
  ) {
    renderObject
      ..factor = factor
      ..hidden = hidden
      ..clipContent = clipContent
      ..surfaceColor = surfaceColor;
  }
}

class _RenderAnimatedExtentSliver extends RenderProxySliver {
  _RenderAnimatedExtentSliver(
    this._factor,
    this._hidden,
    this._clipContent,
    this._surfaceColor,
  );

  static const _edgeGap = 8.0;

  final Paint _washPaint = Paint();

  double _factor;
  double _hidden;
  bool _clipContent;
  Color _surfaceColor;

  bool get clipContent => _clipContent;

  set clipContent(bool value) {
    if (_clipContent == value) return;
    _clipContent = value;
    markNeedsPaint();
  }

  double get factor => _factor;

  set factor(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_factor == next) return;
    _factor = next;
    markNeedsLayout();
    markNeedsPaint();
  }

  double get hidden => _hidden;

  set hidden(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_hidden == next) return;
    _hidden = next;
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
    final hidden = _hidden;
    if (_clipContent && (hidden > 0 || _factor < 1.0)) {
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
    final washExtent = _clipContent
        ? coreExtent
        : max(coreExtent, child?.geometry?.paintExtent ?? 0.0);
    final washSize = isVertical
        ? Size(crossExtent, washExtent)
        : Size(washExtent, crossExtent);
    context.canvas.drawRect(
      (Offset.zero & washSize).shift(offset),
      _washPaint..color = _surfaceColor.withValues(alpha: hidden),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final bool enterAnimated;
  final bool collapsing;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    this.enterAnimated = false,
    this.collapsing = false,
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

  static const _expandButtonWidth = 32.0;
  static const _actionsGap = 6.0;
  static const _actionsRightOffset = _expandButtonWidth + _actionsGap;

  static const _actionsDuration = Duration(milliseconds: 200);

  Widget _buildActionTransition(double value, Widget? child) {
    return Opacity(
      opacity: value,
      child: Transform.scale(
        scale: 0.7 + 0.3 * value,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _wrapAction({required Widget child, required String key}) {
    if (collapsing) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        duration: _actionsDuration,
        curve: Curves.fastOutSlowIn,
        child: child,
        builder: (_, value, c) => _buildActionTransition(value, c),
      );
    }
    if (!enterAnimated) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(key),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: _actionsDuration,
      curve: Curves.fastOutSlowIn,
      builder: (_, value, c) => _buildActionTransition(value, c),
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

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _wrapAction(
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
        _wrapAction(
          key: 'delay_${group.name}',
          child: AnimatedBuilder(
            key: ValueKey('delay_test_${group.name}'),
            animation: delayTestCoordinator,
            builder: (_, _) {
              final isTestingThisGroup = delayTestCoordinator.isTestingGroup(
                group.name,
              );
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
      ],
    );

    final headerRow = Row(
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
        if (isExpand && !collapsing) ...[
          actions,
          const SizedBox(width: _actionsGap),
        ],
        IconButton.filledTonal(
          key: ValueKey('expand_${group.name}'),
          style: _circleFilledTonalStyle,
          iconSize: 24,
          icon: CommonExpandIcon(expand: isExpand),
          onPressed: onToggle,
        ),
      ],
    );

    return CommonCard(
      radius: 20,
      type: CommonCardType.filled,
      onPressed: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Stack(
          children: [
            headerRow,
            if (collapsing)
              Positioned(
                top: 0,
                bottom: 0,
                right: _actionsRightOffset,
                child: Center(child: actions),
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

class _GroupRows {
  final List<Proxy> input;
  final ProxiesSortType sortType;
  final String? testUrl;
  final int columns;
  final num sortNum;
  final List<List<Proxy>> rows;

  const _GroupRows({
    required this.input,
    required this.sortType,
    required this.testUrl,
    required this.columns,
    required this.sortNum,
    required this.rows,
  });
}
