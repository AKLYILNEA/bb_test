import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/plugins/tile.dart';
import 'package:bett_box/plugins/vpn.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'models/models.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  // Init base services
  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized();

  // Set image cache size
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      50 * 1024 * 1024; // 50MB

  final version = await system.version;
  await clashCore.preload();
  await globalState.initApp(version);

  // Init UI
  try {
    await uiManager.initializeUI();
  } catch (e) {
    commonPrint.log('Failed to initialize UI: $e');
  }

  assert(
    _sentryDsn.isNotEmpty,
    'SENTRY_DSN is not set. Build with --dart-define=SENTRY_DSN=<your-dsn>',
  );

  final enableAdvancedAnalytics =
      globalState.config.appSetting.enableCrashReport;

  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.sendDefaultPii = false;
    options.environment = 'production';
    options.release =
        'bettbox@${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}';

    options.enableAutoSessionTracking = true;
    options.attachStacktrace = true;

    if (enableAdvancedAnalytics) {
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
    } else {
      options.tracesSampleRate = 0;
      options.profilesSampleRate = 0;
    }
  }, appRunner: () => _runApp(version));
}

Future<void> _runApp(int version) async {
  if (system.isAndroid && globalState.config.appSetting.enableHighRefreshRate) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      commonPrint.log('Failed to set high refresh rate: $e');
    }
  }
  await android?.init();
  await window?.init(version);
  HttpOverrides.global = BettboxHttpOverrides();
  runApp(ProviderScope(child: const Application()));
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  globalState.isService = true;
  WidgetsFlutterBinding.ensureInitialized();
  final quickStart = flags.contains('quick');
  final clashLibHandler = ClashLibHandler();
  await globalState.init();

  tile?.addListener(
    _TileListenerWithService(
      onStart: () async {
        await app.tip(appLocalizations.startVpn);
        await globalState.handleStart();
      },
      onStop: () async {
        await app.tip(appLocalizations.stopVpn);
        clashLibHandler.stopListener();
        await vpn?.stop();
      },
      onReconnectIpc: () {
        commonPrint.log('Service: reconnectIpc requested, re-establishing IPC');
        _handleMainIpc(clashLibHandler);
      },
    ),
  );

  vpn?.handleGetStartForegroundParams = () async {
    // Check if smart-stopped from native side
    final isSmartStopped = await vpn?.isSmartStopped() ?? false;

    if (isSmartStopped) {
      return json.encode({
        'title': appLocalizations.coreSuspended,
        'content': appLocalizations.smartAutoStopServiceRunning,
      });
    }

    return json.encode({
      'title': appLocalizations.coreConnected,
      'content': appLocalizations.serviceRunning,
    });
  };

  vpn?.addListener(
    _VpnListenerWithService(
      onDnsChanged: (String dns) {
        clashLibHandler.updateDns(dns);
      },
    ),
  );
  final bootStart = flags.contains('boot');
  
  if (!quickStart && !bootStart) {
    _handleMainIpc(clashLibHandler);
  } else {
    // For boot start, only proceed if autoRun is enabled
    if (bootStart && !globalState.config.appSetting.autoRun) {
      commonPrint.log('Silent boot detected, but autoRun is disabled. Staying idle.');
      _handleMainIpc(clashLibHandler);
      return;
    }

    commonPrint.log('Executing ${bootStart ? "boot" : "quick"} start sequence');
    await ClashCore.initGeo();
    app.tip(appLocalizations.startVpn);
    final homeDirPath = await appPath.homeDirPath;
    final version = await system.version;
    final clashConfig = globalState.config.patchClashConfig.copyWith.tun(
      enable: false,
    );
    
    if (system.isAndroid) {
      await vpn?.checkAndCleanResidualVpn();
    }
    
    final params = await globalState.getSetupParams(pathConfig: clashConfig);
    Future(() async {
      final profileId = globalState.config.currentProfileId;
      if (profileId == null) {
        return;
      }
      final res = await clashLibHandler.quickStart(
        InitParams(homeDir: homeDirPath, version: version),
        params,
        globalState.getCoreState(),
      );
      debugPrint(res);
      if (res.isNotEmpty) {
        await vpn?.stop();
        return;
      }
      await vpn?.start(clashLibHandler.getAndroidVpnOptions());
      
      if (globalState.config.appSetting.openLogs) {
        await clashLibHandler.invokeAction('{"id": "quickStartLog", "method": "startLog"}');
      } else {
        await clashLibHandler.invokeAction('{"id": "quickStopLog", "method": "stopLog"}');
      }
      
      clashLibHandler.startListener();
    });
  }
}

void _handleMainIpc(ClashLibHandler clashLibHandler) {
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  if (sendPort == null) {
    return;
  }
  final serviceReceiverPort = ReceivePort();
  serviceReceiverPort.listen((message) async {
    final res = await clashLibHandler.invokeAction(message);
    sendPort.send(res);
  });
  sendPort.send(serviceReceiverPort.sendPort);
  final messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(messageReceiverPort.sendPort.nativePort);
  messageReceiverPort.listen((message) {
    sendPort.send(message);
  });
  // Restart the listener goroutine now that the message port is bound.
  // In quick start, startListener() was called before attachMessagePort,
  // so the goroutine had no port and exited. Re-calling it here ensures
  // log/traffic messages actually flow to the UI Engine.
  clashLibHandler.startListener();
}

@immutable
class _TileListenerWithService with TileListener {
  final Function() _onStart;
  final Function() _onStop;
  final Function() _onReconnectIpc;

  const _TileListenerWithService({
    required Function() onStart,
    required Function() onStop,
    required Function() onReconnectIpc,
  }) : _onStart = onStart,
       _onStop = onStop,
       _onReconnectIpc = onReconnectIpc;

  @override
  void onStart() {
    _onStart();
  }

  @override
  void onStop() {
    _onStop();
  }

  @override
  void onReconnectIpc() {
    _onReconnectIpc();
  }
}

@immutable
class _VpnListenerWithService with VpnListener {
  final Function(String dns) _onDnsChanged;

  const _VpnListenerWithService({required Function(String dns) onDnsChanged})
    : _onDnsChanged = onDnsChanged;

  @override
  void onDnsChanged(String dns) {
    super.onDnsChanged(dns);
    _onDnsChanged(dns);
  }
}
