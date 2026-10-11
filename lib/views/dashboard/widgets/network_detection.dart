import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/add_profile.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  bool _isDisabled = false;
  bool? _optimisticStart;

  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _showIpClickBehaviorSettings() {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    globalState.showCommonDialog<IpClickBehavior>(
      child: CommonDialog(
        title: appLocalizations.ipClickBehavior,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: SuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(FluentIcons.arrow_sync_24_regular),
              title: Text(appLocalizations.manualRefreshIp),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                detectionState.manualRefresh();
              },
            ),
            if (isZh)
              ListTile(
                shape: SuperellipseBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(FluentIcons.cd_16_regular),
                title: Text(appLocalizations.switchToDomesticIp),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  detectionState.switchToDomesticIp();
                },
              ),
            ListTile(
              shape: SuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(
                detectionState.isIpMasked
                    ? FluentIcons.eye_24_regular
                    : FluentIcons.eye_off_24_regular,
              ),
              title: Text(
                detectionState.isIpMasked
                    ? appLocalizations.showCurrentIp
                    : appLocalizations.hideCurrentIp,
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                detectionState.toggleIpPrivacy();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreIpInfoDialog() {
    final ip = detectionState.rawIpInfo?.ip ?? detectionState.state.value.ipInfo?.ip;
    if (ip == null || ip.isEmpty) return;
    showIpDetailDialog(context, ip);
  }

  void _handleStart() async {
    if (_isDisabled) return;
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;
    setState(() {
      _isDisabled = true;
      _optimisticStart = newState;
    });

    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _optimisticStart = null;
        });
      }
    }
  }

  Future<void> _handleLongPress() async {
    final isStart = ref.read(runTimeProvider) != null;
    if (!isStart) return;

    final result = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.restartCoreTitle,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(false);
            },
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(true);
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: Text(appLocalizations.restartCoreDesc),
      ),
    );

    if (result == true) {
      await globalState.appController.restartCore();
      globalState.showNotifier(appLocalizations.success);
    }
  }

  String _formatRunTime(int? timeStamp) {
    if (timeStamp == null) return '00:00:00';

    final diff = timeStamp / 1000;
    int inHours = (diff / 3600).floor();
    int inMinutes = (diff / 60 % 60).floor();
    int inSeconds = (diff % 60).floor();

    if (inHours > 999) {
      inHours = 999;
      inMinutes = 59;
      inSeconds = 59;
    }

    final hourStr = inHours < 100
        ? inHours.toString().padLeft(2, '0')
        : inHours.toString().padLeft(3, '0');
    final minuteStr = inMinutes.toString().padLeft(2, '0');
    final secondStr = inSeconds.toString().padLeft(2, '0');

    return '$hourStr:$minuteStr:$secondStr';
  }

  @override
  Widget build(BuildContext context) {
    final startState = ref.watch(startButtonSelectorStateProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final isRestarting = ref.watch(isRestartingCoreProvider);
    final showLoading = _isDisabled || isRestarting || !startState.isInit;
    final canPress = !showLoading && !isSmartStopped && startState.hasProfile;
    final hasNoProfile = !showLoading && !isSmartStopped && !startState.hasProfile;

    return ValueListenableBuilder<int>(
      valueListenable: dashboardRefreshManager.tick1s,
      builder: (_, _, _) {
        final runTime = ref.read(runTimeProvider);
        final isStart = runTime != null;
        final displayStart = isSmartStopped
            ? false
            : (_optimisticStart ?? isStart);

        return ValueListenableBuilder<NetworkDetectionState>(
          valueListenable: detectionState.state,
          builder: (_, state, _) {
            final ipInfo = state.ipInfo;
            final isLoading = state.isLoading;
            final showFlag = !isLoading && ipInfo != null;
            final flagStyle = Theme.of(context).textTheme.titleMedium?.toLight;
            final flagLineHeight =
                (flagStyle?.height ?? 1.5) *
                globalState.measure.titleSmallHeight /
                globalState.measure.titleMediumHeight;

            return SizedBox(
              height: getWidgetHeight(1),
              child: CommonCard(
                padding: EdgeInsets.zero,
                onPressed: ipInfo != null ? _showMoreIpInfoDialog : () {},
                onLongPress: _showIpClickBehaviorSettings,
                child: Stack(
                  children: [
                    // 左侧主要信息与状态
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: 78.ap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: baseInfoEdgeInsets.copyWith(bottom: 0, right: 0),
                            child: SizedBox(
                              height: globalState.measure.titleSmallHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (showFlag) ...[
                                    EmojiText(
                                      _countryCodeToEmoji(ipInfo.countryCode),
                                      style: flagStyle?.copyWith(height: flagLineHeight),
                                    ),
                                    const SizedBox(width: 8),
                                  ] else ...[
                                    Icon(
                                      FluentIcons.network_check_24_regular,
                                      size: 20.ap,
                                      color: context.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      appLocalizations.networkDetection,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: context.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildStatusPill(
                                    context,
                                    displayStart,
                                    isRestarting,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: baseInfoEdgeInsets.copyWith(top: 0, right: 0),
                            child: SizedBox(
                              height: globalState.measure.bodyMediumHeight + 2,
                              child: isLoading
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: OverflowBox(
                                        alignment: Alignment.centerLeft,
                                        maxWidth: 32,
                                        maxHeight: 16,
                                        child: SpinKitThreeBounce(
                                          color: context.colorScheme.primary,
                                          size: 14,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: _buildIpContent(
                                            context,
                                            state,
                                            ipInfo,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Container(
                                            width: 1.0,
                                            height: 12.ap,
                                            color: context.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        Text(
                                          displayStart ? _formatRunTime(runTime) : '00:00:00',
                                          style: context.textTheme.bodyMedium?.toLight
                                              .adjustSize(1)
                                              .toJetBrainsMono,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 右上角/右侧启动按钮（未运行纯圆，启动时旋转变出多边形）
                    Positioned(
                      right: 16.ap,
                      top: 17.ap,
                      bottom: 17.ap,
                      width: 50.ap,
                      child: _StartButton(
                        isStart: displayStart,
                        canPress: canPress,
                        showLoading: showLoading,
                        isRestarting: isRestarting,
                        hasNoProfile: hasNoProfile,
                        onStart: _handleStart,
                        onLongPress: _handleLongPress,
                        onAddProfile: showAddProfileExtend,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusPill(
    BuildContext context,
    bool isStart,
    bool isRestarting,
  ) {
    final Color dotColor = isRestarting
        ? context.colorScheme.primary
        : isStart
            ? mediaUnlockGreen
            : context.colorScheme.outlineVariant;

    final String text = isRestarting
        ? appLocalizations.coreRestarting
        : isStart
            ? appLocalizations.coreRunning
            : appLocalizations.coreStopped;

    final Color? capsuleColor = isRestarting
        ? context.colorScheme.primary
        : isStart
            ? null
            : context.colorScheme.onSurfaceVariant;

    final Color? capsuleBg = isRestarting
        ? context.colorScheme.primary.withValues(alpha: 0.15)
        : isStart
            ? null
            : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.08);

    final Widget dot = isRestarting
        ? SizedBox(
            width: 8.ap,
            height: 8.ap,
            child: SpinKitFadingCircle(
              color: dotColor,
              size: 8.ap,
            ),
          )
        : Container(
            width: 6.ap,
            height: 6.ap,
            decoration: ShapeDecoration(
              color: dotColor,
              shape: const CircleBorder(),
            ),
          );

    return Transform.translate(
      offset: Offset(0, -1.ap),
      child: CommonInfoCapsule(
        text,
        leading: dot,
        color: capsuleColor,
        backgroundColor: capsuleBg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIpContent(
    BuildContext context,
    NetworkDetectionState state,
    IpInfo? ipInfo,
  ) {
    if (ipInfo != null) {
      final isMasked = detectionState.isIpMasked || ipInfo.ip == '*****';
      return TooltipText(
        text: Text(
          ipInfo.ip,
          style: isMasked
              ? context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.success.opacity80,
                ).toJetBrainsMono.adjustSize(1)
              : context.textTheme.bodyMedium?.toLight
                  .adjustSize(1)
                  .toJetBrainsMono,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Text(
      state.errorMessage ?? 'timeout',
      style: context.textTheme.bodyMedium?.copyWith(color: Colors.red).adjustSize(1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StartButton extends StatefulWidget {
  final bool isStart;
  final bool canPress;
  final bool showLoading;
  final bool isRestarting;
  final bool hasNoProfile;
  final VoidCallback? onStart;
  final VoidCallback? onLongPress;
  final VoidCallback? onAddProfile;

  const _StartButton({
    required this.isStart,
    required this.canPress,
    required this.showLoading,
    required this.isRestarting,
    required this.hasNoProfile,
    this.onStart,
    this.onLongPress,
    this.onAddProfile,
  });

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 650),
    vsync: this,
    value: widget.isStart ? 1.0 : 0.0,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didUpdateWidget(covariant _StartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStart != oldWidget.isStart) {
      if (widget.isStart) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildIcon(BuildContext context) {
    if (widget.showLoading || widget.isRestarting) {
      return OverflowBox(
        key: const ValueKey('loading'),
        maxWidth: 26,
        maxHeight: 16,
        child: SpinKitThreeBounce(
          color: context.colorScheme.onPrimary,
          size: 14,
        ),
      );
    }

    if (widget.isStart) {
      return Icon(
        FluentIcons.align_space_around_vertical_20_filled,
        key: const ValueKey('pause'),
        size: 20.ap,
        color: context.colorScheme.onPrimary,
      );
    }

    return Icon(
      FluentIcons.play_24_filled,
      key: const ValueKey('play'),
      size: 20.ap,
      color: context.colorScheme.onPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final progress = _curve.value;
        final effectiveShape = widget.isStart
            ? MaterialPolygonBorder(polygon: MaterialShapes.cookie12Sided)
            : const CircleBorder();

        return RotationTransition(
          turns: _curve,
          child: Material(
            color: Colors.transparent,
            shape: effectiveShape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.canPress
                  ? widget.onStart
                  : (widget.hasNoProfile ? widget.onAddProfile : null),
              onLongPress: widget.isStart && widget.canPress
                  ? widget.onLongPress
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 纯圆形背景（停止态：使用流量统计次色）
                  if (progress < 1.0)
                    Opacity(
                      opacity: (1.0 - progress).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: globalState.theme.darken2SecondaryContainer,
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  // 多边形背景（启动态，随着旋转慢慢变出）
                  if (progress > 0.0)
                    Opacity(
                      opacity: progress.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * progress,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: context.colorScheme.primary,
                            shape: MaterialPolygonBorder(
                              polygon: MaterialShapes.cookie12Sided,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildIcon(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MaterialPolygonBorder extends ShapeBorder {
  final RoundedPolygon polygon;
  final BorderSide side;

  const MaterialPolygonBorder({
    required this.polygon,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = polygon.toPath();
    final dimension = rect.shortestSide;
    final matrix = Matrix4.identity()
      ..translate(
        rect.left + (rect.width - dimension) / 2,
        rect.top + (rect.height - dimension) / 2,
      )
      ..scale(dimension, dimension);
    return path.transform(matrix.storage);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none && side.width > 0) {
      final paint = side.toPaint();
      canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}
