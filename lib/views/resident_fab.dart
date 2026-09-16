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
/// - 页面切换时外层 `AnimatedSize` 做宽度过渡、内层 `AnimatedSwitcher` 做文案淡入淡出。
class ResidentFab extends ConsumerWidget {
  const ResidentFab({super.key});

  static const _sizeDuration = Duration(milliseconds: 260);
  static const _switchDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageLabel = ref.watch(currentPageLabelProvider);
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final Widget? content = switch (pageLabel) {
      PageLabel.dashboard => const StartFab(),
      PageLabel.profiles => const _AddProfileFab(),
      PageLabel.proxies =>
        proxiesType == ProxiesType.tab ? const _ProxyTestFab() : null,
      _ => null,
    };
    return AnimatedSize(
      duration: _sizeDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: _switchDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: content == null
            ? const SizedBox(
                key: ValueKey('residentFabEmpty'),
                width: 0,
                height: 0,
              )
            : KeyedSubtree(key: ValueKey(pageLabel), child: content),
      ),
    );
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
