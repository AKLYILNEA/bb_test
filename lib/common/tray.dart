import 'dart:async';
import 'dart:io';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'common.dart';

class Tray {
  Timer? _debounceTimer;
  TrayState? _pendingState;
  bool _isUpdating = false;

  static const _debounceDelay = Duration(milliseconds: 300);

  Timer? _loadingTimer;
  int _loadingFrame = 0;
  final List<String> _loadingFrames = ['  .', ' ..', '...'];

  bool _isTesting = false;
  String? _testingGroupId;

  void dispose() {
    _debounceTimer?.cancel();
    _loadingTimer?.cancel();
  }
  Future _updateSystemTray({
    required Brightness? brightness,
    required bool isStart,
    bool force = false,
  }) async {
    if (system.isAndroid) {
      return;
    }
    if (force) {
      await trayManager.destroy();
    }
    await trayManager.setIcon(
      utils.getTrayIconPath(
        brightness:
            brightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
        isStart: isStart,
      ),
      isTemplate: system.isMacOS,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(appName);
    }
  }

  Future<void> update({
    required TrayState trayState,
    bool focus = false,
    bool silent = false,
  }) async {
    if (system.isAndroid) {
      return;
    }

    _debounceTimer?.cancel();

    if (_isUpdating) {
      _pendingState = trayState;
      return;
    }

    if (focus) {
      await _doUpdate(trayState: trayState, focus: focus);
    } else if (silent) {
      _debounceTimer = Timer(const Duration(milliseconds: 50), () async {
        await _doUpdate(trayState: trayState, focus: focus, silent: silent);
      });
    } else {
      _debounceTimer = Timer(_debounceDelay, () async {
        await _doUpdate(trayState: trayState, focus: focus);
      });
    }
  }

  Future<void> _doUpdate({
    required TrayState trayState,
    bool focus = false,
    bool silent = false,
  }) async {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      if (!silent && !Platform.isLinux) {
        await _updateSystemTray(
          brightness: trayState.brightness,
          isStart: trayState.isStart,
          force: focus,
        );
      }
    List<MenuItem> menuItems = [];
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        window?.show();
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem.checkbox(
      label: trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      onClick: (_) async {
        globalState.appController.updateStart();
      },
      checked: false,
    );
    menuItems.add(startMenuItem);
    menuItems.add(MenuItem.separator());
    for (final mode in Mode.values) {
      menuItems.add(
        MenuItem.checkbox(
          label: Intl.message(mode.name),
          onClick: (_) {
            globalState.appController.changeMode(mode);
          },
          checked: mode == trayState.mode,
        ),
      );
    }
    menuItems.add(MenuItem.separator());
    if (trayState.trayEnhancement) {
      for (final group in trayState.groups) {
        List<MenuItem> subMenuItems = [];

        final isTestingThisGroup = _isTesting && _testingGroupId == group.name;

        subMenuItems.add(
          MenuItem(
            label: isTestingThisGroup
                ? '⚡ ${appLocalizations.startTest}...'
                : '⚡ ${appLocalizations.startTest}',
            disabled: _isTesting,
            onClick: (_) => _testGroupDelay(group),
          ),
        );

        subMenuItems.add(MenuItem.separator());

        for (final proxy in group.all) {
          final delay = trayState.delays[proxy.name];
          final label = _formatProxyLabel(proxy.name, delay);

          subMenuItems.add(
            MenuItem.checkbox(
              label: label,
              checked: group.getCurrentSelectedName(trayState.selectedMap[group.name] ?? '') == proxy.name,
              onClick: (_) {
                final appController = globalState.appController;
                appController.updateCurrentSelectedMap(group.name, proxy.name);
                appController.changeProxy(
                  groupName: group.name,
                  proxyName: proxy.name,
                );
              },
            ),
          );
        }
        menuItems.add(
          MenuItem.submenu(
            label: group.name,
            submenu: Menu(items: subMenuItems),
          ),
        );
      }
      if (trayState.groups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
    }
    if (trayState.isStart) {
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.tun,
          onClick: (_) {
            globalState.appController.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.systemProxy,
          onClick: (_) {
            globalState.appController.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(MenuItem.separator());
    }
    final autoStartMenuItem = MenuItem.checkbox(
      label: appLocalizations.autoLaunch,
      onClick: (_) async {
        globalState.appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final copyEnvVarMenuItem = MenuItem(
      label: appLocalizations.copyEnvVar,
      onClick: (_) async {
        await _copyEnv(trayState.port);
      },
    );
    menuItems.add(autoStartMenuItem);
    menuItems.add(copyEnvVarMenuItem);

    if (!system.isAndroid) {
      final wakelockMenuItem = MenuItem.checkbox(
        label: appLocalizations.wakelock,
        onClick: (_) async {
          await _toggleWakelock();
        },
        checked: trayState.wakelockEnabled,
      );
      menuItems.add(wakelockMenuItem);
    }

    menuItems.add(MenuItem.separator());
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await globalState.appController.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(
      menu,
      keepMenuOpen: silent,
      brightness: trayState.brightness,
    );
    if (Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        isStart: trayState.isStart,
        force: focus,
      );
    }
    } finally {
      _isUpdating = false;

      if (_pendingState != null) {
        final pending = _pendingState;
        _pendingState = null;
        await _doUpdate(trayState: pending!, focus: false);
      }
    }
  }

  Future<void> _copyEnv(int port) async {
    final url = 'http://127.0.0.1:$port';

    final cmdline = system.isWindows
        ? 'set \$env:all_proxy=$url'
        : 'export all_proxy=$url';

    await Clipboard.setData(ClipboardData(text: cmdline));
  }

  Future<void> _toggleWakelock() async {
    try {
      final enabled = await WakelockPlus.enabled;
      if (enabled) {
        await WakelockPlus.disable();
        globalState.appController.stopWakelockAutoRecovery();
      } else {
        await WakelockPlus.enable();
        globalState.appController.startWakelockAutoRecovery();
      }
      globalState.updateWakelockState(!enabled);
      await globalState.appController.updateTray();
    } catch (e) {
      commonPrint.log('WakeLock toggle error: $e');
    }
  }

  String _formatProxyLabel(String name, int? delay) {
    final sep = system.isWindows ? '\t' : '  ';
    if (delay == null) {
      return name;
    } else if (delay == 0) {
      final frame = _loadingFrames[_loadingFrame];
      return '$name$sep$frame';
    } else if (delay < 0) {
      return '$name$sep×';
    } else {
      return '$name$sep${delay}ms';
    }
  }

  void _startLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingFrame = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      _loadingFrame = (_loadingFrame + 1) % _loadingFrames.length;
      if (!trayManager.isMenuOpen) {
        await globalState.appController.updateTray(false, true);
      }
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _loadingFrame = 0;
  }

  Future<void> _testGroupDelay(Group group) async {
    if (_isTesting) return;

    final appController = globalState.appController;
    final testUrl = appController.getRealTestUrl('');

    final testableProxies = group.all.where((p) {
      final name = p.name.toUpperCase();
      return name != 'REJECT' && name != 'REJECT-DROP' && name != 'PASS';
    }).toList();

    _isTesting = true;
    _testingGroupId = group.name;

    try {

      for (final proxy in testableProxies) {
        appController.setDelay(Delay(
          url: testUrl,
          name: proxy.name,
          value: 0,
        ));
      }

      _startLoadingAnimation();

      await globalState.appController.updateTray(false, true);

      await delayTest(testableProxies);
    } catch (e) {
      commonPrint.log('Delay test error: $e');
      for (final proxy in testableProxies) {
        appController.setDelay(Delay(
          url: testUrl,
          name: proxy.name,
          value: -1,
        ));
      }
    } finally {
      _stopLoadingAnimation();

      _isTesting = false;
      _testingGroupId = null;

      await globalState.appController.updateTray(false, true);
    }
  }
}

final tray = Tray();
