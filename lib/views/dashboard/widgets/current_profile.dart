import 'dart:async';
import 'dart:math';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'core_status_dialog.dart';

class CurrentProfile extends ConsumerStatefulWidget {
  const CurrentProfile({super.key});

  @override
  ConsumerState<CurrentProfile> createState() => _CurrentProfileState();
}

class _CurrentProfileState extends ConsumerState<CurrentProfile> {
  late final VoidCallback _tickListener;
  static TrafficValue _lastMemoryValue = TrafficValue(value: 0);
  static int _lastInUse = 0;
  static int _lastReclaimable = 0;

  TrafficValue _memoryValue = _lastMemoryValue;
  int _inUse = _lastInUse;
  int _reclaimable = _lastReclaimable;
  Timer? _initTimer;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tickListener = _updateMemoryStatus;
    dashboardRefreshManager.tick2s.addListener(_tickListener);

    if (_lastMemoryValue.value == 0) {
      _retryUpdateMemory();
    } else {
      _initTimer = Timer(const Duration(milliseconds: 1000), _updateMemoryStatus);
    }
  }

  Future<void> _retryUpdateMemory() async {
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      await _updateMemoryStatus();
      if (_memoryValue.value > 0) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    dashboardRefreshManager.tick2s.removeListener(_tickListener);
    super.dispose();
  }

  Future<void> _updateMemoryStatus() async {
    if (!mounted) return;
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final status = await clashCore.getCoreStatus();
      if (status != null && (status.inUse > 0 || status.physical > 0)) {
        final currentInUse = status.inUse > 0 ? status.inUse : status.physical;
        if (mounted) {
          setState(() {
            _inUse = currentInUse;
            _reclaimable = status.reclaimable;
            _memoryValue = TrafficValue(value: currentInUse);
            _lastInUse = _inUse;
            _lastReclaimable = _reclaimable;
            _lastMemoryValue = _memoryValue;
          });
        }
      } else {
        // Fallback to getMemory() if core status is not available
        final mem = await clashCore.getMemory();
        if (mem > 0 && mounted) {
          setState(() {
            _inUse = mem;
            _memoryValue = TrafficValue(value: mem);
            _lastInUse = _inUse;
            _lastMemoryValue = _memoryValue;
          });
        }
      }
    } catch (_) {
    } finally {
      _isUpdating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final totalMem = _inUse + _reclaimable;
    final int flexInUse;
    final int flexReclaim;

    if (totalMem > 0) {
      flexInUse = max((_inUse / totalMem * 100).round(), 1);
      flexReclaim = max((_reclaimable / totalMem * 100).round(), 1);
    } else {
      flexInUse = 70;
      flexReclaim = 30;
    }

    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        padding: EdgeInsets.zero,
        onPressed: () => showCoreStatusDialog(context),
        onLongPress: () => showCoreStatusDialog(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上半部分：当前配置
            Padding(
              padding: EdgeInsets.fromLTRB(16.ap, 14.ap, 12.ap, 12.ap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: globalState.measure.titleSmallHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.rocket_24_regular,
                          size: 20.ap,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appLocalizations.currentProfile,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 28.ap,
                          height: 28.ap,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              FluentIcons.settings_24_regular,
                              size: 18.ap,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              if (profile != null) {
                                showCurrentProfileDialog();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.ap),
                  Text(
                    profile?.label ?? appLocalizations.notAcquired,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18.ap,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 分割线
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.ap),
              child: Container(
                height: 1.0,
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            // 下半部分：内存信息
            Padding(
              padding: EdgeInsets.fromLTRB(16.ap, 12.ap, 16.ap, 16.ap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appLocalizations.memoryInfo,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10.ap),
                  // 双色水平进度条（内核负载详情可分配和可回收颜色）
                  Row(
                    children: [
                      Expanded(
                        flex: flexInUse,
                        child: Container(
                          height: 12.ap,
                          decoration: ShapeDecoration(
                            color: context.colorScheme.primary,
                            shape: SuperellipseBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.ap),
                      Expanded(
                        flex: flexReclaim,
                        child: Container(
                          height: 12.ap,
                          decoration: ShapeDecoration(
                            color: context.colorScheme.tertiary,
                            shape: SuperellipseBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.ap),
                  // 内存数值大字号呈现
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _memoryValue.showValue,
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 24.ap,
                            color: context.colorScheme.onSurface,
                          ).toJetBrainsMono,
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: _memoryValue.showUnit,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                            fontSize: 16.ap,
                            fontWeight: FontWeight.w500,
                          ).toJetBrainsMono,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
