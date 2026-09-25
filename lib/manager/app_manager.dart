import 'dart:async';
import 'dart:math' as math;

import 'package:bett_box/clash/core.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/manager/window_manager.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  bool _isRefreshActive = false;
  bool _wasPaused = false;
  Timer? _dashboardRefreshDebounceTimer;
  Timer? _missedUpdateCheckTimer;
  DateTime? _lastMissedUpdateCheck;
  late final VoidCallback _dashboardTickListener;

  static const _missedUpdateCheckDelay = Duration(seconds: 5);
  static const _missedUpdateCheckThrottle = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardTickListener = () {
      if (!globalState.isStart) {
        return;
      }
      unawaited(globalState.appController.updateRunTime());
    };
    dashboardRefreshManager.tick1s.addListener(_dashboardTickListener);
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.computeHeightMapCache = {};
        }
      });
    });
    ref.listenManual(checkIpProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        detectionState.startCheck();
      }
    });
    ref.listenManual(checkMediaUnlockProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        mediaUnlockState.startCheckOnNodeChange();
      }
    });
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDashboardRefreshState();
      detectionState.tryStartCheck();
      mediaUnlockState.tryStartCheck();
      globalState.appController.updateGroupsDebounce();
    });
    if (window == null) {
      return;
    }
    ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
      if (prev == next) {
        return;
      }
      final shouldSet = next.a == true && next.b == true;
      await macOS?.updateDns(!shouldSet);
      await system.setupLinuxTunDns(shouldSet);
    });
    ref.listenManual(currentBrightnessProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      window?.updateMacOSBrightness(next);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _dashboardRefreshDebounceTimer?.cancel();
    _missedUpdateCheckTimer?.cancel();
    dashboardRefreshManager.tick1s.removeListener(_dashboardTickListener);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _updateDashboardRefreshState() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    var isVisible = true;
    var isMinimized = false;
    if (system.isDesktop) {
      final visible = await window?.isVisible;
      if (visible == false) {
        isVisible = false;
      }
      isMinimized = await window?.isMinimized ?? false;
    }
    final isPinned =
        system.isDesktop &&
        ref.read(windowSettingProvider.select((s) => s.isPinned));
    final shouldRun = system.isDesktop
        ? (isPinned || (isVisible && !isMinimized))
        : isForeground;

    if (!shouldRun) {
      _dashboardRefreshDebounceTimer?.cancel();
      _dashboardRefreshDebounceTimer = null;
      if (_isRefreshActive) {
        dashboardRefreshManager.stop();
        _isRefreshActive = false;
      }
      return;
    }

    if (_isRefreshActive) {
      return;
    }

    _dashboardRefreshDebounceTimer?.cancel();
    _dashboardRefreshDebounceTimer = Timer(
      const Duration(milliseconds: 1000),
      () {
        if (!mounted) return;
        if (_isRefreshActive) return;
        dashboardRefreshManager.start();
        _isRefreshActive = true;
      },
    );
  }

  bool get _shouldCheckMissedUpdates {
    if (_lastMissedUpdateCheck == null) return true;
    return DateTime.now().difference(_lastMissedUpdateCheck!) >
        _missedUpdateCheckThrottle;
  }

  void _scheduleMissedUpdateCheck() {
    if (!_shouldCheckMissedUpdates) return;
    _missedUpdateCheckTimer?.cancel();
    _missedUpdateCheckTimer = Timer(_missedUpdateCheckDelay, () {
      _lastMissedUpdateCheck = DateTime.now();
      globalState.appController.checkAndUpdateMissedProfiles();
    });
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
    }

    final isBackgroundState =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !system.isDesktop);

    if (isBackgroundState) {
      _missedUpdateCheckTimer?.cancel();
      globalState.appController.savePreferences();
      await globalState.handleBackground();
    } else if (state == AppLifecycleState.resumed) {
      globalState.handleForeground();
      render?.resume();
      await globalState.resumeForegroundUpdates();
      await globalState.appController.syncWakelockIfNeeded();
      _scheduleMissedUpdateCheck();
      final isInit = await clashCore.isInit;
      if (isInit) {
        globalState.appController.updateGroupsDebounce();
      }

      if (_wasPaused) {
        _wasPaused = false;
        final hasDetection = ref
            .read(dashboardStateProvider)
            .dashboardWidgets
            .contains(DashboardWidget.networkDetection);
        if (hasDetection) {
          detectionState.tryStartCheck();
        }
        mediaUnlockState.tryStartCheck();
      }
    }
    if (state == AppLifecycleState.resumed && system.isAndroid) {
      final hidden = ref.read(appSettingProvider.select((s) => s.hidden));
      app.updateExcludeFromRecents(hidden);
      SystemChrome.setSystemUIOverlayStyle(
        globalState.appState.systemUiOverlayStyle,
      );
    }
    _updateDashboardRefreshState();
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness();
    globalState.appController.updateTray();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  Widget _buildLoading() {
    return Consumer(
      builder: (_, ref, _) {
        final loading = ref.watch(loadingProvider);
        final isMobileView = ref.watch(isMobileViewProvider);
        return loading && !isMobileView
            ? RotatedBox(
                quarterTurns: 1,
                child: const LinearProgressIndicator(),
              )
            : Container();
      },
    );
  }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    final isLight = context.colorScheme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh,
        border: Border(
          right: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(
              alpha: isLight ? 0.6 : 0.45,
            ),
          ),
        ),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }

  double _calculateExtendedWidth(
    BuildContext context,
    List<NavigationItem> items,
  ) {
    final labelStyle =
        context.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    double maxTextWidth = 0.0;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    for (final item in items) {
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

    return math.max(96.0, (72.0 + maxTextWidth + 28.0).ceilToDouble());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;
    final extendedWidth = _calculateExtendedWidth(context, navigationItems);
    return Row(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            _buildBackground(
              context: context,
              child: SafeArea(
                left: true,
                top: true,
                right: false,
                bottom: false,
                child: Column(
                  children: [
                    if (system.isMacOS) const SizedBox(height: 22),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: HiddenBarScrollBehavior(),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: IntrinsicHeight(
                                  child: CallbackShortcuts(
                                    bindings: <ShortcutActivator, VoidCallback>{
                                      const SingleActivator(
                                        LogicalKeyboardKey.arrowUp,
                                      ): () {
                                        if (currentIndex > 0) {
                                          globalState.appController.toPage(
                                            navigationItems[currentIndex - 1]
                                                .label,
                                          );
                                        }
                                      },
                                      const SingleActivator(
                                        LogicalKeyboardKey.arrowDown,
                                      ): () {
                                        if (currentIndex <
                                            navigationItems.length - 1) {
                                          globalState.appController.toPage(
                                            navigationItems[currentIndex + 1]
                                                .label,
                                          );
                                        }
                                      },
                                      const SingleActivator(
                                        LogicalKeyboardKey.select,
                                      ): () {},
                                      const SingleActivator(
                                        LogicalKeyboardKey.enter,
                                      ): () {},
                                    },
                                    child: Focus(
                                      autofocus: true,
                                      child: NavigationRail(
                                        minExtendedWidth: extendedWidth,
                                        backgroundColor: Colors.transparent,
                                        indicatorColor: context
                                            .colorScheme
                                            .primary
                                            .withValues(
                                              alpha:
                                                  context
                                                          .colorScheme
                                                          .brightness ==
                                                      Brightness.light
                                                  ? 0.20
                                                  : 0.26,
                                            ),
                                        indicatorShape:
                                            const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(16),
                                              ),
                                            ),
                                        selectedIconTheme: IconThemeData(
                                          color: context.colorScheme.primary,
                                        ),
                                        unselectedIconTheme: IconThemeData(
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        selectedLabelTextStyle: context
                                            .textTheme
                                            .labelLarge!
                                            .copyWith(
                                              color:
                                                  context.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        unselectedLabelTextStyle: context
                                            .textTheme
                                            .labelLarge!
                                            .copyWith(
                                              color: context
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        destinations: navigationItems
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              final index = entry.key;
                                              final e = entry.value;
                                              final isSelected =
                                                  currentIndex == index;
                                              return NavigationRailDestination(
                                                icon: AnimatedNavIcon(
                                                  label: e.label,
                                                  selected: isSelected,
                                                  color: isSelected
                                                      ? context
                                                            .colorScheme
                                                            .primary
                                                      : context
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                                label: Text(
                                                  e.label.localizedName,
                                                ),
                                              );
                                            })
                                            .toList(),
                                        onDestinationSelected: (index) {
                                          final label =
                                              navigationItems[index].label;
                                          if (currentIndex == index) {
                                            final pageContext = GlobalObjectKey(
                                              label,
                                            ).currentContext;
                                            if (pageContext != null) {
                                              Navigator.of(pageContext)
                                                  .popUntil(
                                                    (route) => route.isFirst,
                                                  );
                                            }
                                          }
                                          globalState.appController.toPage(
                                            label,
                                          );
                                        },
                                        extended: showLabel,
                                        selectedIndex: currentIndex,
                                        labelType: NavigationRailLabelType.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: showLabel ? extendedWidth : 72.0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 72.0,
                          child: Center(
                            child: IconButton(
                              tooltip: context.appLocalizations.toggleLabel,
                              onPressed: () {
                                ref
                                    .read(appSettingProvider.notifier)
                                    .update(
                                      (state) => state.copyWith(
                                        showLabel: !state.showLabel,
                                      ),
                                    );
                              },
                              icon: SidebarToggleIcon(
                                expanded: showLabel,
                                size: 20.0,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildLoading(),
          ],
        ),
        Expanded(
          flex: 1,
          child: ClipRect(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
