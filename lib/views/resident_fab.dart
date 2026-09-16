import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/views/dashboard/widgets/start_fab.dart';
import 'package:bett_box/views/profiles/add_profile.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// OverflowBoxFit 没有经由 material/widgets 再导出，需要显式从 rendering 取
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// 移动视图（竖屏）下与底栏伴生的常驻悬浮按钮。
///
/// - 只在这三个根页面出现对应操作：首页 = 启动/停止、代理 = 测速、配置 = 添加配置；
/// - 「更多」页以及代理页切到列表模式（`ProxiesType.list`）时不显示；
/// - 其它页面（脚本、隧道、日志、请求、连接、资源）完全不参与，它们各自的悬浮按钮保持原样；
/// - 页面之间切换时，**外壳（底色 / 圆角 / 阴影 / FAB 本体）全程只存在一个实例、完全不淡出**，
///   只做「内部内容淡出 → 替换 → label 宽度连续变宽 + 内容淡入」，
///   与首页启动/停止按钮（`start_fab.dart` 的 `AnimatedContainer` 200ms easeOut）
///   使用同一时长与同一套测量方式，因此既不会两块按钮叠加变亮，也不会出现直角或闪现位移；
/// - 出现 / 消失（例如切到「更多」页）时才是整体弱隐。
class ResidentFab extends ConsumerStatefulWidget {
  const ResidentFab({super.key});

  @override
  ConsumerState<ResidentFab> createState() => _ResidentFabState();
}

class _ResidentFabState extends ConsumerState<ResidentFab>
    with TickerProviderStateMixin {
  /// 页面之间切换：只让内部图标与文字忽隐忽现（外壳不动）
  static const _contentFadeIn = Duration(milliseconds: 180);
  static const _contentFadeOut = Duration(milliseconds: 110);

  /// 出现 / 消失：整体弱隐
  static const _shellFadeIn = Duration(milliseconds: 180);
  static const _shellFadeOut = Duration(milliseconds: 130);

  late final AnimationController _contentFade = AnimationController(
    vsync: this,
    duration: _contentFadeIn,
    reverseDuration: _contentFadeOut,
    value: 1.0,
  );

  late final AnimationController _shellFade = AnimationController(
    vsync: this,
    duration: _shellFadeIn,
    reverseDuration: _shellFadeOut,
  );

  /// 代理页测速时的内容缩放，沿用 DelayTestButton 的实现（1 → 0）
  late final AnimationController _testScaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _testScale = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).animate(
    CurvedAnimation(parent: _testScaleController, curve: const Interval(0, 1)),
  );

  /// 当前真正渲染的根页面（过渡期间保持旧值，等内容淡出结束再替换；
  /// 非常驻页面不会覆盖它，这样回到常驻页面时内容还是对的那一个）
  PageLabel? _renderedPage;
  bool _renderedVisible = false;

  /// 已经登记过的目标，用来避免同一目标被反复调度
  PageLabel? _pendingPage;
  bool? _pendingVisible;

  /// 换页序号：新目标到来时让上一轮过渡自行退出，避免排队等待
  int _switchGeneration = 0;

  /// 代理页当前策略组名（测速按钮据此判断是否正在测速）
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    delayTestCoordinator.addListener(_handleTestingChanged);
    _handleTestingChanged();
  }

  void _handleTestingChanged() {
    if (!mounted) return;
    if (delayTestCoordinator.isTestingGroup(_groupName)) {
      _testScaleController.forward();
    } else {
      _testScaleController.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    delayTestCoordinator.removeListener(_handleTestingChanged);
    _contentFade.dispose();
    _shellFade.dispose();
    _testScaleController.dispose();
    super.dispose();
  }

  void _handleProxyTest(VoidCallback? action) {
    if (delayTestCoordinator.isTesting) return;
    action?.call();
  }

  /// 顺序执行，绝不让两段动画叠加：
  /// 同一页面可见性下换页 = 只淡出内容；出现 / 消失 = 只淡入淡出外壳。
  Future<void> _switch(PageLabel? page, bool visible) async {
    final generation = ++_switchGeneration;
    final wasVisible = _renderedVisible;

    if (wasVisible && visible) {
      await _contentFade.reverse();
      if (!mounted || generation != _switchGeneration) return;
    }

    if (!mounted || generation != _switchGeneration) return;

    setState(() {
      if (page != null) {
        _renderedPage = page;
      }
      _renderedVisible = visible;
    });

    if (!visible) {
      if (wasVisible) {
        await _shellFade.reverse();
        if (!mounted || generation != _switchGeneration) return;
      }
      // 不可见期间内容直接回到完整状态，下次出现只做整体淡入
      _contentFade.value = 1.0;
      return;
    }

    if (wasVisible) {
      _contentFade.forward();
      return;
    }

    _contentFade.value = 1.0;
    await _shellFade.forward();
  }

  @override
  Widget build(BuildContext context) {
    final pageLabel = ref.watch(currentPageLabelProvider);
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final residentPage = switch (pageLabel) {
      PageLabel.dashboard => PageLabel.dashboard,
      PageLabel.profiles => PageLabel.profiles,
      PageLabel.proxies => proxiesType == ProxiesType.tab
          ? PageLabel.proxies
          : null,
      _ => null,
    };
    final visible = residentPage != null;
    _groupName =
        ref.watch(proxiesTabControllerStateProvider.select((state) => state.b)) ??
        '';
    final proxyTestAction = ref.watch(residentProxyTestProvider);

    if (_pendingPage != residentPage || _pendingVisible != visible) {
      _pendingPage = residentPage;
      _pendingVisible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _switch(residentPage, visible);
      });
    }

    return StartFabDataProvider(
      builder: (context, startData) => AnimatedBuilder(
        animation: _testScaleController.view,
        builder: (context, _) {
          return _ResidentFabShell(
            content: _buildContent(context, startData, proxyTestAction),
            contentFade: _contentFade,
            shellFade: _shellFade,
            visible: _renderedVisible,
            // 只有屏幕上看得见的时候才连续变宽，不可见期间直接到位
            animateWidth: _shellFade.value > 0,
          );
        },
      ),
    );
  }

  _FabContent _buildContent(
    BuildContext context,
    StartFabData startData,
    VoidCallback? proxyTestAction,
  ) {
    switch (_renderedPage) {
      case PageLabel.dashboard:
        return _FabContent(
          icon: startData.icon,
          labelText: startData.labelText,
          labelWidth: startData.labelWidth,
          onPressed: startData.onPressed,
          onLongPress: startData.onLongPress,
          contentOpacity: startData.showLoading ? 0.0 : 1.0,
          showLoading: startData.showLoading,
        );
      case PageLabel.profiles:
        return _FabContent(
          icon: Icons.add_rounded,
          labelText: appLocalizations.addProfile,
          labelWidth: startFabTextWidth(context, appLocalizations.addProfile),
          onPressed: showAddProfileExtend,
        );
      case PageLabel.proxies:
        return _FabContent(
          icon: Icons.network_ping_rounded,
          labelText: appLocalizations.startTest,
          labelWidth: startFabTextWidth(context, appLocalizations.startTest),
          onPressed: (delayTestCoordinator.isTesting || _groupName.isEmpty)
              ? null
              : () => _handleProxyTest(proxyTestAction),
          contentScale: _testScale.value,
          showLoading:
              delayTestCoordinator.isTestingGroup(_groupName) &&
              _testScaleController.isCompleted,
        );
      default:
        // 首帧（还没登记目标）用启动按钮的数据兜底；此时外壳是完全透明的
        return _FabContent(
          icon: startData.icon,
          labelText: startData.labelText,
          labelWidth: startData.labelWidth,
          onPressed: startData.onPressed,
          onLongPress: startData.onLongPress,
          contentOpacity: startData.showLoading ? 0.0 : 1.0,
          showLoading: startData.showLoading,
        );
    }
  }
}

/// 常驻悬浮按钮当前要显示的内容
@immutable
class _FabContent {
  const _FabContent({
    required this.icon,
    required this.labelText,
    required this.labelWidth,
    this.onPressed,
    this.onLongPress,
    this.contentOpacity = 1.0,
    this.contentScale = 1.0,
    this.showLoading = false,
  });

  final IconData icon;
  final String labelText;
  final double labelWidth;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double contentOpacity;
  final double contentScale;
  final bool showLoading;
}

/// 常驻悬浮按钮的外壳。
///
/// 底色、圆角、阴影、FAB 本体全程只渲染这一个实例，页面之间不重建、不淡出；
/// 变化的只有 label 的宽度（`AnimatedContainer`，与启动/停止按钮同款）
/// 以及图标 / 文字的透明度。
class _ResidentFabShell extends StatelessWidget {
  const _ResidentFabShell({
    required this.content,
    required this.contentFade,
    required this.shellFade,
    required this.visible,
    required this.animateWidth,
  });

  final _FabContent content;
  final Animation<double> contentFade;
  final Animation<double> shellFade;
  final bool visible;
  final bool animateWidth;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: shellFade,
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          onLongPress: content.onLongPress,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: getCommonFabDecoration(context),
                child: FloatingActionButton.extended(
                  elevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  clipBehavior: Clip.none,
                  heroTag: null,
                  onPressed: content.onPressed,
                  icon: _buildContentChild(Icon(content.icon)),
                  // 与图标走同一个内容包装：加载中（showLoading）时图标与文字一起隐藏、
                  // 只留加载点阵（冷启动时内核状态还没初始化，之前文字没跟着隐藏，
                  // 就出现了文字和加载动画重叠）；代理页测速时两者也一起缩放
                  label: _buildContentChild(
                    AnimatedContainer(
                      // 看不见的时候宽度直接到位，只有看得见才连续变宽
                      duration: animateWidth
                          ? startFabWidthAnimationDuration
                          : Duration.zero,
                      curve: Curves.easeOut,
                      width: content.labelWidth,
                      alignment: Alignment.center,
                      // 文字必须先按自身宽度单行排版，再整体居中：
                      // 宽度动画期间 label 盒子会比新文字窄，若直接放 Text（默认 softWrap），
                      // 中文会在窄盒里折行、只画出前两个字，等盒子变宽才整段显示，
                      // 表现为「最后一下卡顿展开」。
                      // 注意 fit 必须是 deferToChild：OverflowBox 默认的 max 是 sizedByParent，
                      // 尺寸会取 constraints.biggest，把整个 label 区撑到父级允许的最大宽度，
                      // 结果图标被顶到最左、文字被挤出屏幕之外。
                      child: OverflowBox(
                        fit: OverflowBoxFit.deferToChild,
                        alignment: Alignment.center,
                        minWidth: 0,
                        maxWidth: double.infinity,
                        child: Text(
                          content.labelText,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          style: startFabLabelStyle(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (content.showLoading)
                IgnorePointer(
                  child: SizedBox(
                    width: 30,
                    height: 16,
                    child: OverflowBox(
                      maxWidth: 30,
                      maxHeight: 16,
                      child: SpinKitThreeBounce(
                        color:
                            Theme.of(
                              context,
                            ).floatingActionButtonTheme.foregroundColor ??
                            context.colorScheme.onPrimaryContainer,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentChild(Widget child) {
    // 结构必须恒定：这里曾经按 `contentScale != 1` 决定要不要包 Transform.scale，
    // 于是测速进行中切到首页时（scale ≠ 1 → 1）整棵子树换了形状、被重建，
    // label 里的 AnimatedContainer 拿到的是新初始宽度，宽度动画直接消失
    // （表现就是「按钮直接变长、没有动画」）。
    // scale = 1 / opacity = 1 都是无副作用的恒等包装，所以无条件保留。
    return FadeTransition(
      opacity: contentFade,
      child: Opacity(
        opacity: content.contentOpacity,
        child: Transform.scale(scale: content.contentScale, child: child),
      ),
    );
  }
}
