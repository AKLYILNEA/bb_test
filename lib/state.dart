import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Pointer;

import 'package:animations/animations.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/theme.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/plugins/service.dart';
import 'package:bett_box/providers/state.dart' as providers_state;
import 'package:bett_box/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as flutter_riverpod;
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'controller.dart';
import 'models/models.dart';

typedef UpdateTasks = List<FutureOr Function()>;

class GlobalState {
  static GlobalState? _instance;
  Map<CacheTag, FixedMap<String, double>> computeHeightMapCache = {};

  // Map<CacheTag, double> computeScrollPositionCache = {};
  // final Map<String, double> scrollPositionCache = {};
  bool isService = false;
  Timer? timer;
  Timer? groupsUpdateTimer;
  late Config config;
  late AppState appState;
  bool isPre = true;
  String? coreSHA256;
  late PackageInfo packageInfo;
  Function? updateCurrentDelayDebounce;
  late Measure measure;
  late CommonTheme theme;
  late Color accentColor;
  CorePalette? corePalette;
  DateTime? startTime;
  UpdateTasks tasks = [];
  final navigatorKey = GlobalKey<NavigatorState>();
  AppController? _appController;

  // Config rollback: backup last successful config params
  SetupParams? _lastSuccessfulSetupParams;

  // GlobalKey<CommonScaffoldState> homeScaffoldKey = GlobalKey();
  bool isInit = false;

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  AppController get appController => _appController!;

  set appController(AppController appController) {
    _appController = appController;
    isInit = true;
  }

  GlobalState._internal();

  factory GlobalState() {
    _instance ??= GlobalState._internal();
    return _instance!;
  }

  Future<void> initApp(int version) async {
    coreSHA256 = const String.fromEnvironment('CORE_SHA256');
    isPre = const String.fromEnvironment('APP_ENV') != 'stable';
    appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    await _initDynamicColor();
    await init();
  }

  Future<void> _initDynamicColor() async {
    try {
      corePalette = await DynamicColorPlugin.getCorePalette();
      accentColor =
          await DynamicColorPlugin.getAccentColor() ??
          Color(defaultPrimaryColor);
    } catch (_) {}
  }

  Future<void> init() async {
    packageInfo = await PackageInfo.fromPlatform();
    config =
        await preferences.getConfig() ?? Config(themeProps: defaultThemeProps);
    await globalState.migrateOldData(config);
    await AppLocalizations.load(
      utils.getLocaleForString(config.appSetting.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
  }

  String get ua => config.patchClashConfig.globalUa ?? packageInfo.ua;

  Future<void> startUpdateTasks([UpdateTasks? tasks]) async {
    if (timer != null && timer!.isActive == true) return;
    if (tasks != null) {
      this.tasks = tasks;
    }
    await executorUpdateTask();
    timer = Timer(const Duration(seconds: 1), () async {
      startUpdateTasks();
    });
  }

  Future<void> executorUpdateTask() async {
    for (final task in tasks) {
      await task();
    }
    timer = null;
  }

  void stopUpdateTasks() {
    if (timer == null || timer?.isActive == false) return;
    timer?.cancel();
    timer = null;
  }

  Future<void> handleStart([UpdateTasks? tasks]) async {
    startTime ??= DateTime.now();
    await clashCore.startListener();
    await service?.startVpn();
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.setBool('is_vpn_running', true);
    // Desktop: record TUN running state (detect resource conflicts after update)
    if (system.isDesktop) {
      final tunEnabled = config.patchClashConfig.tun.enable;
      await prefs?.setBool('is_tun_running', tunEnabled);
    }
    // Android: sync quick response state (disable if smartAutoStop is on to prevent conflicts)
    if (system.isAndroid) {
      final conflictFreeQuickResponse =
          config.vpnProps.quickResponse && !config.vpnProps.smartAutoStop;
      await service?.setQuickResponse(conflictFreeQuickResponse);
    }
    startUpdateTasks(tasks);
  }

  Future updateStartTime() async {
    startTime = await clashLib?.getRunTime();
  }

  void updateWakelockState(bool enabled) {
    // Update synced wakelock state
    if (_appController != null) {
      final container = _appController!.context;
      if (container.mounted) {
        // Get ProviderContainer using ProviderScope.containerOf
        final providerContainer = flutter_riverpod.ProviderScope.containerOf(
          container,
          listen: false,
        );
        providerContainer
                .read(providers_state.wakelockStateProvider.notifier)
                .state =
            enabled;
      }
    }
  }

  Future handleStop() async {
    startTime = null;
    await clashCore.stopListener();
    await service?.stopVpn();
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.setBool('is_vpn_running', false);
    // Desktop: clear TUN running state
    if (system.isDesktop) {
      await prefs?.setBool('is_tun_running', false);
    }
    stopUpdateTasks();
  }

  Future<bool?> showMessage({
    String? title,
    required InlineSpan message,
    String? confirmText,
    bool cancelable = true,
  }) async {
    return await showCommonDialog<bool>(
      child: Builder(
        builder: (context) {
          return CommonDialog(
            title: title ?? appLocalizations.tip,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              ),
            ],
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [message],
                  ),
                  style: const TextStyle(overflow: TextOverflow.visible),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Future<Map<String, dynamic>> getProfileMap(String id) async {
  //   final profilePath = await appPath.getProfilePath(id);
  //   final res = await Isolate.run<Result<dynamic>>(() async {
  //     try {
  //       final file = File(profilePath);
  //       if (!await file.exists()) {
  //         return Result.error("");
  //       }
  //       final value = await file.readAsString();
  //       return Result.success(utils.convertYamlNode(loadYaml(value)));
  //     } catch (e) {
  //       return Result.error(e.toString());
  //     }
  //   });
  //   if (res.isSuccess) {
  //     return res.data as Map<String, dynamic>;
  //   } else {
  //     throw res.message;
  //   }
  // }

  Future<T?> showCommonDialog<T>({
    required Widget child,
    bool dismissible = true,
  }) async {
    return await showModal<T>(
      context: navigatorKey.currentState!.context,
      configuration: FadeScaleTransitionConfiguration(
        barrierColor: Colors.black38,
        barrierDismissible: dismissible,
      ),
      builder: (_) => child,
      filter: commonFilter,
    );
  }

  void showNotifier(String text) {
    if (text.isEmpty) {
      return;
    }
    navigatorKey.currentContext?.showNotifier(text);
  }

  Future<void> openUrl(String url) async {
    final res = await showMessage(
      message: TextSpan(text: url),
      title: appLocalizations.externalLink,
      confirmText: appLocalizations.go,
    );
    if (res != true) {
      return;
    }
    launchUrl(Uri.parse(url));
  }

  Future<void> migrateOldData(Config config) async {
    final clashConfig = await preferences.getClashConfig();
    if (clashConfig != null) {
      config = config.copyWith(patchClashConfig: clashConfig);
      preferences.clearClashConfig();
      preferences.saveConfig(config);
    }
  }

  CoreState getCoreState() {
    final currentProfile = config.currentProfile;
    return CoreState(
      vpnProps: config.vpnProps,
      onlyStatisticsProxy: config.appSetting.onlyStatisticsProxy,
      currentProfileName: currentProfile?.label ?? currentProfile?.id ?? '',
      bypassDomain: config.networkProps.bypassDomain,
    );
  }

  Future<SetupParams> getSetupParams({required ClashConfig pathConfig}) async {
    final clashConfig = await patchRawConfig(patchConfig: pathConfig);
    final params = SetupParams(
      config: clashConfig,
      selectedMap: config.currentProfile?.selectedMap ?? {},
      testUrl: config.appSetting.testUrl,
    );
    return params;
  }

  /// Backup successful config for rollback
  void backupSuccessfulConfig(SetupParams params) {
    _lastSuccessfulSetupParams = params;
    commonPrint.log('Current config protected');
  }

  /// Get last successful config for rollback
  SetupParams? getLastSuccessfulConfig() {
    return _lastSuccessfulSetupParams;
  }

  Future<Map<String, dynamic>> patchRawConfig({
    required ClashConfig patchConfig,
  }) async {
    final profile = config.currentProfile;
    if (profile == null) {
      return {};
    }
    final profileId = profile.id;
    final configMap = await getProfileConfig(profileId);
    final rawConfig = await handleEvaluate(configMap);
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(
        config.networkProps.routeMode,
        fakeIpRange: patchConfig.dns.fakeIpRange,
        fakeIpRangeV6: patchConfig.dns.fakeIpRangeV6,
      ),
    );
    rawConfig['external-controller'] = realPatchConfig.externalController.value;
    // Auto-set secret when external controller is enabled
    if (realPatchConfig.externalController == ExternalControllerStatus.open) {
      final secret = realPatchConfig.secret;
      if (secret != null && secret.isNotEmpty) {
        rawConfig['secret'] = secret;
      }
    }
    rawConfig['external-ui'] = await appPath.uiPath;
    rawConfig['interface-name'] = '';
    rawConfig['tcp-concurrent'] = realPatchConfig.tcpConcurrent;
    rawConfig['unified-delay'] = realPatchConfig.unifiedDelay;
    rawConfig['ipv6'] = realPatchConfig.ipv6;
    rawConfig['log-level'] = realPatchConfig.logLevel.name;
    rawConfig['port'] = 0;
    rawConfig['socks-port'] = 0;
    rawConfig['keep-alive-interval'] = realPatchConfig.keepAliveInterval;
    rawConfig['mixed-port'] = realPatchConfig.mixedPort;
    rawConfig['port'] = realPatchConfig.port;
    rawConfig['socks-port'] = realPatchConfig.socksPort;
    rawConfig['redir-port'] = realPatchConfig.redirPort;
    rawConfig['tproxy-port'] = realPatchConfig.tproxyPort;
    rawConfig['find-process-mode'] = realPatchConfig.findProcessMode.name;
    rawConfig['allow-lan'] = realPatchConfig.allowLan;
    rawConfig['mode'] = realPatchConfig.mode.name;
    if (rawConfig['tun'] == null) {
      rawConfig['tun'] = {};
    }
    rawConfig['tun']['enable'] = realPatchConfig.tun.enable;
    rawConfig['tun']['device'] = realPatchConfig.tun.device;
    rawConfig['tun']['dns-hijack'] = realPatchConfig.tun.dnsHijack;
    rawConfig['tun']['stack'] = realPatchConfig.tun.stack.name;
    rawConfig['tun']['route-address'] = realPatchConfig.tun.routeAddress;
    rawConfig['tun']['auto-route'] = realPatchConfig.tun.autoRoute;
    rawConfig['tun']['disable-icmp-forwarding'] =
        realPatchConfig.tun.disableIcmpForwarding;
    rawConfig['tun']['mtu'] = realPatchConfig.tun.mtu;
    rawConfig['geodata-loader'] = realPatchConfig.geodataLoader.name;
    if (rawConfig['sniffer']?['sniff'] != null) {
      for (final value in (rawConfig['sniffer']?['sniff'] as Map).values) {
        if (value['ports'] != null && value['ports'] is List) {
          value['ports'] =
              value['ports']?.map((item) => item.toString()).toList() ?? [];
        }
      }
    }
    if (rawConfig['profile'] == null) {
      rawConfig['profile'] = {};
    }
    if (rawConfig['proxy-providers'] != null) {
      final proxyProviders = rawConfig['proxy-providers'] as Map;
      for (final key in proxyProviders.keys) {
        final proxyProvider = proxyProviders[key];
        if (proxyProvider['type'] != 'http') {
          continue;
        }
        if (proxyProvider['url'] != null) {
          proxyProvider['path'] = await appPath.getProvidersFilePath(
            profile.id,
            'proxies',
            proxyProvider['url'],
          );
        }
      }
    }

    if (rawConfig['rule-providers'] != null) {
      final ruleProviders = rawConfig['rule-providers'] as Map;
      for (final key in ruleProviders.keys) {
        final ruleProvider = ruleProviders[key];
        if (ruleProvider['type'] != 'http') {
          continue;
        }
        if (ruleProvider['url'] != null) {
          ruleProvider['path'] = await appPath.getProvidersFilePath(
            profile.id,
            'rules',
            ruleProvider['url'],
          );
        }
      }
    }

    rawConfig['profile']['store-selected'] = true;
    rawConfig['geox-url'] = realPatchConfig.geoXUrl.toJson();
    rawConfig['global-ua'] = realPatchConfig.globalUa;
    if (rawConfig['hosts'] == null) {
      rawConfig['hosts'] = {};
    }
    for (final host in realPatchConfig.hosts.entries) {
      rawConfig['hosts'][host.key] = host.value.splitByMultipleSeparators;
    }

    // Force add Windows NCSI (Network Connectivity Status Indicator) hosts
    // Ensure Windows network connectivity detection works properly
    rawConfig['hosts']['dns.msftncsi.com'] = [
      '131.107.255.255',
      'fd3e:4f5a:5b81::1',
    ];

    if (rawConfig['dns'] == null) {
      rawConfig['dns'] = {};
    }
    final isEnableDns = rawConfig['dns']['enable'] == true;
    final overrideDns = globalState.config.overrideDns;
    if (overrideDns || !isEnableDns) {
      final dns = switch (!isEnableDns) {
        true => realPatchConfig.dns.copyWith(
          nameserver: [...realPatchConfig.dns.nameserver, 'system://'],
        ),
        false => realPatchConfig.dns,
      };
      rawConfig['dns'] = dns.toJson();
      rawConfig['dns']['nameserver-policy'] = {};
      for (final entry in dns.nameserverPolicy.entries) {
        rawConfig['dns']['nameserver-policy'][entry.key] =
            entry.value.splitByMultipleSeparators;
      }
    }

    if (rawConfig['ntp'] == null) {
      rawConfig['ntp'] = {};
    }
    final overrideNtp = globalState.config.overrideNtp;
    if (overrideNtp) {
      final ntp = realPatchConfig.ntp;
      rawConfig['ntp'] = ntp.toJson();
    }
    if (rawConfig['sniffer'] == null) {
      rawConfig['sniffer'] = {};
    }
    final overrideSniffer = globalState.config.overrideSniffer;
    if (overrideSniffer) {
      final sniffer = realPatchConfig.sniffer;
      rawConfig['sniffer'] = sniffer.toJson();
    }
    // Tunnel append logic: append GUI tunnels to config file tunnels
    final guiTunnels = realPatchConfig.tunnels;
    if (guiTunnels.isNotEmpty) {
      // Get existing tunnels from config file
      final existingTunnels = rawConfig['tunnels'] as List? ?? [];
      // Append GUI tunnels to existing tunnels
      final allTunnels = [
        ...existingTunnels,
        ...guiTunnels.map((t) => t.toClashJson()),
      ];
      rawConfig['tunnels'] = allTunnels;
    }
    if (rawConfig['experimental'] == null) {
      rawConfig['experimental'] = {};
    }
    final overrideExperimental = globalState.config.overrideExperimental;
    if (overrideExperimental) {
      final experimental = realPatchConfig.experimental;
      rawConfig['experimental'] = experimental.toJson();
    }
    var rules = [];
    // Support both field names: rules (plural) and rule (singular)
    if (rawConfig['rules'] != null) {
      rules = rawConfig['rules'];
      rawConfig.remove('rules');
    } else if (rawConfig['rule'] != null) {
      rules = rawConfig['rule'];
      rawConfig.remove('rule');
    }

    final overrideData = profile.overrideData;
    if (overrideData.enable && config.scriptProps.currentScript == null) {
      if (overrideData.rule.type == OverrideRuleType.override) {
        rules = overrideData.runningRule;
      } else {
        rules = [...overrideData.runningRule, ...rules];
      }
    }

    // Ensure private network direct rules, ensure priority matching
    // Desktop only, Android bypassed via VPN routing
    if (system.isDesktop &&
        config.networkProps.routeMode == RouteMode.bypassPrivate) {
      final privateNetworkRules = [
        'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
        'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
        'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
        'IP-CIDR,169.254.0.0/16,DIRECT,no-resolve',
        'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
        'IP-CIDR6,fd00::/8,DIRECT,no-resolve',
        'IP-CIDR6,fe80::/10,DIRECT,no-resolve',
      ];
      rules = [...privateNetworkRules, ...rules];
    }

    // FCM optimization: add mtalk.google.com direct rule
    if (config.vpnProps.fcmOptimization) {
      final fcmRules = ['DOMAIN,mtalk.google.com,DIRECT'];
      rules = [...fcmRules, ...rules];
    }

    rawConfig['rule'] = rules;
    return rawConfig;
  }

  Future<Map<String, dynamic>> getProfileConfig(String profileId) async {
    final configMap = await switch (clashLibHandler != null) {
      true => clashLibHandler!.getConfig(profileId),
      false => clashCore.getConfig(profileId),
    };
    configMap['rules'] = configMap['rule'];
    configMap.remove('rule');
    return configMap;
  }

  Future<Map<String, dynamic>> handleEvaluate(
    Map<String, dynamic> config,
  ) async {
    final currentScript = globalState.config.scriptProps.currentScript;
    if (currentScript == null) {
      return config;
    }
    if (config['proxy-providers'] == null) {
      config['proxy-providers'] = {};
    }
    final configJs = json.encode(config);
    final runtime = getJavascriptRuntime();
    final res = await runtime.evaluateAsync('''
      ${currentScript.content}
      main($configJs)
    ''');
    if (res.isError) {
      throw res.stringResult;
    }
    final value = switch (res.rawResult is Pointer) {
      true => runtime.convertValue<Map<String, dynamic>>(res),
      false => Map<String, dynamic>.from(res.rawResult),
    };
    return value ?? config;
  }
}

class DashboardRefreshManager {
  Timer? _timer1s;
  Timer? _timer2s;
  Timer? _timer5s;
  bool _isRunning = false;

  final tick1s = ValueNotifier<int>(0);
  final tick2s = ValueNotifier<int>(0);
  final tick5s = ValueNotifier<int>(0);

  bool get isRunning => _isRunning;

  Future<bool> _isActive() async {
    if (globalState.appState.pageLabel != PageLabel.dashboard) {
      return false;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    if (system.isDesktop) {
      final visible = await window?.isVisible;
      if (visible == false) {
        return false;
      }
    }
    return true;
  }

  Future<void> _tryTick(ValueNotifier<int> notifier) async {
    if (!await _isActive()) {
      return;
    }
    notifier.value++;
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer1s = Timer.periodic(const Duration(seconds: 1), (_) {
      _tryTick(tick1s);
    });
    _timer2s = Timer.periodic(const Duration(seconds: 2), (_) {
      _tryTick(tick2s);
    });
    _timer5s = Timer.periodic(const Duration(seconds: 5), (_) {
      _tryTick(tick5s);
    });
  }

  void stop() {
    if (!_isRunning) return;
    _timer1s?.cancel();
    _timer2s?.cancel();
    _timer5s?.cancel();
    _timer1s = null;
    _timer2s = null;
    _timer5s = null;
    _isRunning = false;
  }
}

final dashboardRefreshManager = DashboardRefreshManager();

final globalState = GlobalState();

class DetectionState {
  static DetectionState? _instance;
  bool? _preIsStart;
  int _requestId = 0; // Request ID to prevent old requests overwriting new ones
  CancelToken? _cancelToken;
  bool _isIpMasked = false; // IP privacy protection state
  IpInfo? _originalIpInfo; // Save original IP info
  bool _isFirstLaunch = true; // First launch flag

  final state = ValueNotifier<NetworkDetectionState>(
    const NetworkDetectionState(
      isLoading: true,
      ipInfo: null,
      errorMessage: null,
    ),
  );

  DetectionState._internal();

  factory DetectionState() {
    _instance ??= DetectionState._internal();
    return _instance!;
  }

  bool get isIpMasked => _isIpMasked;

  // Toggle IP privacy
  void toggleIpPrivacy() {
    _isIpMasked = !_isIpMasked;
    final currentIpInfo = state.value.ipInfo;
    if (currentIpInfo != null) {
      if (_isIpMasked) {
        _originalIpInfo = currentIpInfo;
        state.value = state.value.copyWith(
          ipInfo: currentIpInfo.copyWith(ip: '*** *** *** ***'),
        );
      } else {
        if (_originalIpInfo != null) {
          state.value = state.value.copyWith(ipInfo: _originalIpInfo);
          _originalIpInfo = null;
        }
      }
    }
  }

  // Manual refresh IP
  void manualRefresh() {
    _isIpMasked = false;
    _originalIpInfo = null;
    startCheck();
  }

  // Switch to domestic IP (use domestic API)
  Future<void> switchToDomesticIp() async {
    _isIpMasked = false;
    _originalIpInfo = null;

    _cancelPreviousRequest();
    _cancelToken = CancelToken();
    final requestId = ++_requestId;

    state.value = state.value.copyWith(
      isLoading: true,
      ipInfo: null,
      errorMessage: null,
    );

    final res = await request.checkIpDomestic(cancelToken: _cancelToken);

    // Check if latest request
    if (requestId != _requestId) return;

    _handleResponse(res);
  }

  void startCheck() {
    // Pre-check conditions
    final appState = globalState.appState;
    if (!appState.isInit) return;
    if (appState.pageLabel != PageLabel.dashboard) return;

    // Reduce delay on first launch for faster response
    final delay = _isFirstLaunch
        ? const Duration(milliseconds: 500) // First: 500ms
        : const Duration(milliseconds: 1500); // Later: 1.5s

    debouncer.call(FunctionTag.checkIp, _checkIp, duration: delay);
  }

  void tryStartCheck() {
    // Trigger check in these cases:
    // 1. Never checked (_preIsStart == null)
    // 2. Error state (error message but no IP)
    if (!state.value.isLoading &&
        state.value.ipInfo == null &&
        (_preIsStart == null || state.value.errorMessage != null)) {
      startCheck();
    }
  }

  void _cancelPreviousRequest() {
    if (_cancelToken != null) {
      _cancelToken!.cancel();
      _cancelToken = null;
    }
  }

  void _handleResponse(Result<IpInfo?> res) {
    if (res.isError) {
      // Request cancelled, no error shown
      if (res.message == 'cancelled') {
        state.value = state.value.copyWith(
          isLoading: false,
          ipInfo: null,
          errorMessage: null,
        );
        return;
      }
      // Other errors
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: null,
        errorMessage: appLocalizations.tryManualRefresh,
      );
      return;
    }

    final ipInfo = res.data;
    if (ipInfo != null) {
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: ipInfo,
        errorMessage: null,
      );
    } else {
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: null,
        errorMessage: appLocalizations.tryManualRefresh,
      );
    }
  }

  Future<void> _checkIp() async {
    final appState = globalState.appState;

    // Simplified pre-check: keep only core conditions
    if (!appState.isInit) return;
    if (appState.pageLabel != PageLabel.dashboard) return;

    // Remove lifecycle and window visibility checks for stability

    final isStart = appState.runTime != null;

    // Optimization: if VPN off and cached data exists, return
    if (!isStart && state.value.ipInfo != null && !state.value.isLoading) {
      return;
    }

    _preIsStart = isStart;
    _cancelPreviousRequest();
    _cancelToken = CancelToken();
    final requestId = ++_requestId;

    // Set loading state, clear old IP to show loading animation
    state.value = state.value.copyWith(
      isLoading: true,
      errorMessage: null,
      ipInfo: null, // Clear old IP, show loading
    );

    // First launch uses shorter timeout for quick failure
    final timeout = _isFirstLaunch
        ? const Duration(seconds: 3) // First: 3s
        : const Duration(seconds: 5); // Later: 5s

    // When off, use domestic API by default
    final res = isStart
        ? await request.checkIp(cancelToken: _cancelToken, timeout: timeout)
        : await request.checkIpDomestic(
            cancelToken: _cancelToken,
            timeout: timeout,
          );

    // Check if latest request
    if (requestId != _requestId) return;

    // First launch failure: retry after delay
    if (_isFirstLaunch && (res.isError || res.data == null)) {
      _isFirstLaunch = false;
      _handleResponse(res);

      // Auto-retry after 3s
      Future.delayed(const Duration(seconds: 3), () {
        if (state.value.ipInfo == null && !state.value.isLoading) {
          startCheck();
        }
      });
    } else {
      _isFirstLaunch = false;
      _handleResponse(res);
    }
  }
}

final detectionState = DetectionState();
