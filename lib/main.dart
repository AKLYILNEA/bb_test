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
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'l10n/l10n.dart';
import 'l10n/intl/messages_all.dart' show initializeMessages;
import 'models/models.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

ReceivePort? _serviceReceiverPort;
ReceivePort? _messageReceiverPort;

Future<void> _initSentryAndRun(Future<void> Function() runner) async {
  assert(
    _sentryDsn.isNotEmpty,
    'SENTRY_DSN is not set. Build with --dart-define=SENTRY_DSN=<your-dsn>',
  );

  final enableAdvancedAnalytics =
      globalState.config.appSetting.enableCrashReport;

  if (!enableAdvancedAnalytics) {
    await runner();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.sendDefaultPii = false;
    options.environment = 'production';
    options.release =
        'bettbox@${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}';

    options.enableAutoSessionTracking = true;
    options.attachStacktrace = true;

    options.tracesSampleRate = 0.2;

    options.beforeSend = (event, hint) {
      if (system.isMacOS) {
        final hasFontDeadlock =
            event.threads?.any(
              (thread) =>
                  thread.stacktrace?.frames.any(
                    (frame) =>
                        frame.function?.contains('XTCopyPropertiesForFont') ==
                            true ||
                        frame.function?.contains('TGlobalFontRegistryImp') ==
                            true ||
                        frame.function?.contains(
                              '__NSXPCCONNECTION_IS_WAITING_FOR_A_SYNCHRONOUS_REPLY__',
                            ) ==
                            true,
                  ) ??
                  false,
            ) ??
            false;

        if (hasFontDeadlock) {
          event.level = SentryLevel.warning;
          event.tags = {
            ...?event.tags,
            'known_issue': 'macos_font_deadlock',
            'system_issue': 'fontd_service',
          };
        }
      }
      return event;
    };
  }, appRunner: runner);
}

Future<void> main() async {
  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  final version = await system.version;
  await clashCore.preload();
  await globalState.initApp(version);

  try {
    await uiManager.initializeUI();
  } catch (e) {
    commonPrint.log('Failed to initialize UI: $e');
  }

  await _initSentryAndRun(() => _runApp(version));
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
  await globalState.init();

  await _initSentryAndRun(() async {
    final quickStart = flags.contains('quick');
    final bootStart = flags.contains('boot');
    final clashLibHandler = ClashLibHandler();

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
          commonPrint.log(
            'Service: reconnectIpc requested, re-establishing IPC',
          );
          _handleMainIpc(clashLibHandler);
        },
      ),
    );

    vpn?.handleGetStartForegroundParams = () async {
      final locale = utils.getLocaleForString(
        globalState.config.appSetting.locale,
      ) ?? utils.getSystemLocale();

      await AppLocalizations.load(const Locale('zh', 'CN'));
      if (locale != const Locale('zh', 'CN')) {
        final localeName = Intl.canonicalizedLocale(
          (locale.countryCode?.isEmpty ?? true)
              ? locale.languageCode
              : locale.toString(),
        );
        if (await initializeMessages(localeName)) {
          await AppLocalizations.load(locale);
        }
      }

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

    if (!quickStart && !bootStart) {
      _handleMainIpc(clashLibHandler);
      return;
    }

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

    final params = await globalState.getSetupParams(pathConfig: clashConfig);
    Future(() async {
      try {
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
          commonPrint.log('QuickStart failed with error: $res');
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
      } catch (e, stackTrace) {
        commonPrint.log('Fatal error during service background start: $e');
        Sentry.captureException(e, stackTrace: stackTrace);
        await vpn?.stop();
      }
    });
  });
}

void _handleMainIpc(ClashLibHandler clashLibHandler) {
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  if (sendPort == null) {
    commonPrint.log('Service: mainIsolate sendPort not found, IPC unavailable');
    return;
  }

  _serviceReceiverPort?.close();
  _messageReceiverPort?.close();

  _serviceReceiverPort = ReceivePort();
  _serviceReceiverPort!.listen((message) async {
    final res = await clashLibHandler.invokeAction(message);
    _safeSend(sendPort, res);
  });
  _safeSend(sendPort, _serviceReceiverPort!.sendPort);

  _messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(_messageReceiverPort!.sendPort.nativePort);
  _messageReceiverPort!.listen((message) {
    _safeSend(sendPort, message);
  });

  clashLibHandler.startListener();
}

void _safeSend(SendPort sendPort, dynamic message) {
  try {
    sendPort.send(message);
  } catch (e) {
    commonPrint.log('Service: IPC send failed: $e');
    final retryPort = IsolateNameServer.lookupPortByName(mainIsolate);
    if (retryPort != null) {
      try {
        retryPort.send(message);
      } catch (_) {}
    }
  }
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
  void onStart() => _onStart();

  @override
  void onStop() => _onStop();

  @override
  void onReconnectIpc() => _onReconnectIpc();
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
