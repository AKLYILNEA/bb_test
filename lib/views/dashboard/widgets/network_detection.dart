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
                    // 右侧装饰背景水波
                    Positioned(
                      right: -24.ap,
                      top: -24.ap,
                      bottom: -24.ap,
                      width: 132.ap,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _MaterialShapePainter(
                            shape: MaterialShapes.softBoom,
                            color: context.colorScheme.primary.withValues(
                              alpha: Theme.of(context).colorScheme.brightness == Brightness.dark
                                  ? 0.16
                                  : 0.10,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                                  if (ipInfo != null) ...[
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: _buildIpContent(
                                      context,
                                      state,
                                      ipInfo,
                                      isLoading,
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
                    // 右上角/右侧启动按钮
                    Positioned(
                      right: 16.ap,
                      top: 17.ap,
                      bottom: 17.ap,
                      width: 50.ap,
                      child: Material(
                        color: context.colorScheme.primary,
                        shape: MaterialPolygonBorder(
                          polygon: MaterialShapes.cookie12Sided,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: canPress
                              ? _handleStart
                              : (hasNoProfile ? showAddProfileExtend : null),
                          onLongPress: isStart && canPress ? _handleLongPress : null,
                          child: Center(
                            child: _buildStartButtonIcon(
                              context,
                              displayStart,
                              showLoading,
                              isRestarting,
                            ),
                          ),
                        ),
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
            ? context.colorScheme.success
            : context.colorScheme.outlineVariant;

    final Color pillBg = isRestarting || isStart
        ? context.colorScheme.primary.withValues(alpha: 0.12)
        : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.08);

    final Color textColor = isRestarting || isStart
        ? context.colorScheme.primary
        : context.colorScheme.onSurfaceVariant;

    final String text = isRestarting
        ? appLocalizations.coreRestarting
        : isStart
            ? appLocalizations.coreRunning
            : appLocalizations.coreStopped;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.ap,
          height: 7.ap,
          decoration: ShapeDecoration(
            color: dotColor,
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.ap, vertical: 2.ap),
          decoration: ShapeDecoration(
            color: pillBg,
            shape: SuperellipseBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11.ap,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIpContent(
    BuildContext context,
    NetworkDetectionState state,
    IpInfo? ipInfo,
    bool isLoading,
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

    if (isLoading == false) {
      return Text(
        state.errorMessage ?? 'timeout',
        style: context.textTheme.bodyMedium?.copyWith(color: Colors.red).adjustSize(1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return OverflowBox(
      maxWidth: 30,
      maxHeight: 16,
      child: SpinKitThreeBounce(
        color: context.colorScheme.primary,
        size: 14,
      ),
    );
  }

  Widget _buildStartButtonIcon(
    BuildContext context,
    bool isStart,
    bool showLoading,
    bool isRestarting,
  ) {
    if (showLoading || isRestarting) {
      return OverflowBox(
        maxWidth: 26,
        maxHeight: 16,
        child: SpinKitThreeBounce(
          color: context.colorScheme.onPrimary,
          size: 14,
        ),
      );
    }

    if (isStart) {
      return Icon(
        FluentIcons.align_space_around_vertical_20_filled,
        size: 20.ap,
        color: context.colorScheme.onPrimary,
      );
    }

    return Icon(
      FluentIcons.play_24_filled,
      size: 20.ap,
      color: context.colorScheme.onPrimary,
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

class _MaterialShapePainter extends CustomPainter {
  final RoundedPolygon shape;
  final Color color;

  _MaterialShapePainter({required this.shape, required this.color});

  late final Path _path = shape.toPath();

  @override
  void paint(Canvas canvas, Size size) {
    final dimension = size.shortestSide;
    final offset = Offset(
      (size.width - dimension) / 2,
      (size.height - dimension) / 2,
    );
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(dimension);
    canvas.drawPath(_path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaterialShapePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}
