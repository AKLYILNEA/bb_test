import 'dart:ui' show FontVariation;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/views/dashboard/widgets/start_fab.dart';
import 'package:bett_box/views/profiles/add_profile.dart';
import 'package:bett_box/views/proxies/tab.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 移动视图（竖屏）下与底栏伴生的常驻悬浮按钮。
///
/// - 只在这三个根页面出现对应操作：首页 = 启动/停止、代理 = 测速、配置 = 添加配置；
/// - 「更多」页以及代理页切到列表模式（`ProxiesType.list`）时不显示；
/// - 其它页面（脚本、隧道、日志、请求、连接、资源）完全不参与，它们各自的悬浮按钮保持原样；
/// - 切换页面时**只做顺序淡出 → 换内容 → 淡入**（绝不叠两个按钮），
///   宽度交给 [AnimatedSize] 平滑过渡且不裁剪，因此不会出现变亮、阴影闪烁或直角。
class ResidentFab extends ConsumerStatefulWidget {
  const ResidentFab({super.key});

  @override
  ConsumerState<ResidentFab> createState() => _ResidentFabState();
}

class _ResidentFabState extends ConsumerState<ResidentFab>
    with SingleTickerProviderStateMixin {
  static const _fadeIn = Duration(milliseconds: 180);
  static const _fadeOut = Duration(milliseconds: 110);

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _fadeIn,
    reverseDuration: _fadeOut,
  );

  /// 当前真正渲染的页面（切换过程中保持旧值，等淡出结束再换）
  PageLabel? _renderedPage;
  bool _renderedVisible = false;
  bool _transitioning = false;

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// 顺序执行：先淡出旧内容，再替换、淡入新内容。
  /// 期间再来新目标就记下来，等这一轮结束再执行，避免两段动画叠加。
  Future<void> _switch(
    PageLabel page,
    bool visible, {
    PageLabel? pendingPage,
    bool? pendingVisible,
  }) async {
    if (_transitioning) {
      return;
    }
    _transitioning = true;
    if (_fade.value > 0) {
      await _fade.reverse();
    }
    if (!mounted) {
      _transitioning = false;
      return;
    }
    setState(() {
      _renderedPage = pendingPage ?? page;
      _renderedVisible = pendingVisible ?? visible;
    });
    _transitioning = false;
    if (_renderedVisible) {
      _fade.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageLabel = ref.watch(currentPageLabelProvider);
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final visible = switch (pageLabel) {
      PageLabel.dashboard || PageLabel.profiles => true,
      PageLabel.proxies => proxiesType == ProxiesType.tab,
      _ => false,
    };
    if (_renderedPage != pageLabel || _renderedVisible != visible) {
      final nextPage = pageLabel;
      final nextVisible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // 还在过渡中就直接跳到最终状态，避免排队等待带来的卡顿
        if (_transitioning) {
          setState(() {
            _renderedPage = nextPage;
            _renderedVisible = nextVisible;
          });
          return;
        }
        _switch(nextPage, nextVisible);
      });
    }
    final content = _buildContent(_renderedPage);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      // 不裁剪：否则宽度变化过程中圆角会被切成直角
      clipBehavior: Clip.none,
      child: FadeTransition(
        opacity: _fade,
        child: IgnorePointer(
          ignoring: !_renderedVisible,
          child: content,
        ),
      ),
    );
  }

  Widget _buildContent(PageLabel? pageLabel) {
    return switch (pageLabel) {
      PageLabel.dashboard => const StartFab(),
      PageLabel.profiles => const _AddProfileFab(),
      PageLabel.proxies => const _ProxyTestFab(),
      _ => const SizedBox.shrink(),
    };
  }
}

/// 配置页状态：添加配置（外观与动作沿用页面原来的实现）
class _AddProfileFab extends StatelessWidget {
  const _AddProfileFab();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: getCommonFabDecoration(context),
      child: FloatingActionButton.extended(
        elevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        clipBehavior: Clip.none,
        heroTag: null,
        onPressed: showAddProfileExtend,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          appLocalizations.addProfile,
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
            fontWeight: FontWeight.bold,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      ),
    );
  }
}

/// 代理页状态（策略组标签模式）：当前策略组测速。
/// 动作由代理页在挂载时注册到 [residentProxyTestProvider]。
class _ProxyTestFab extends ConsumerWidget {
  const _ProxyTestFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentGroupName = ref.watch(
      proxiesTabControllerStateProvider.select((state) => state.b),
    );
    final action = ref.watch(residentProxyTestProvider);
    return DelayTestButton(
      groupName: currentGroupName ?? '',
      onClick: () async {
        action?.call();
      },
    );
  }
}
