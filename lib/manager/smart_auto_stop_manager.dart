import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/network_matcher.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/plugins/service.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Smart Auto Stop Manager
class SmartAutoStopManager extends ConsumerStatefulWidget {
  final Widget child;

  const SmartAutoStopManager({super.key, required this.child});

  @override
  ConsumerState<SmartAutoStopManager> createState() =>
      _SmartAutoStopManagerState();
}

class _SmartAutoStopManagerState extends ConsumerState<SmartAutoStopManager> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _lastCheckedIp;

  static const _serviceChannel = MethodChannel('service');

  @override
  void initState() {
    super.initState();
    _initConnectivityListener();
    _initNativeNetworkListener();
  }

  void _initNativeNetworkListener() {
    _serviceChannel.setMethodCallHandler((call) async {
      if (call.method == 'networkChanged') {
        _onNativeNetworkChanged();
      } else if (call.method == 'quickResponse') {
        final vpnProps = ref.read(vpnSettingProvider);
        if (vpnProps.quickResponse) {
          commonPrint.log(
            'Quick Response triggered on network change: closing connections.',
          );
          clashCore.closeConnections();
        }
      }
    });
  }

  void _onNativeNetworkChanged() {
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) return;
    Future.delayed(const Duration(milliseconds: 1000), () {
      _checkCurrentNetwork();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to VPN settings changes to trigger check immediately if enabled
    ref.listenManual(vpnSettingProvider, (prev, next) {
      if (prev?.smartAutoStop != next.smartAutoStop ||
          prev?.smartAutoStopNetworks != next.smartAutoStopNetworks) {
        _onSettingsChanged();
      }
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      _onConnectivityChanged(results);
    });
  }

  void _onSettingsChanged() {
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) {
      // Feature disabled, if we were smart-stopped, resume.
      final isSmartStopped = ref.read(isSmartStoppedProvider);
      if (isSmartStopped) {
        ref.read(isSmartStoppedProvider.notifier).set(false);
        _restartVpn();
      }
      return;
    }
    // Re-check current network
    _checkCurrentNetwork();
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) return;

    // Delay a bit to let network stabilize
    await Future.delayed(const Duration(milliseconds: 1000));
    await _checkCurrentNetwork();
  }

  Future<void> _checkCurrentNetwork() async {
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) return;

    final networks = vpnProps.smartAutoStopNetworks;
    // Empty networks rule = disable feature effectively
    if (networks.isEmpty) return;

    // 1. Determine reliable Running state
    bool isRunning;
    if (system.isAndroid) {
      // On Android, always sync with native side
      await globalState.updateStartTime();
      // Also check runTimeProvider as a fallback/confirmation
      isRunning = globalState.isStart;
    } else {
      isRunning = ref.read(runTimeProvider) != null;
    }

    final isSmartStopped = ref.read(isSmartStoppedProvider);

    // 2. Get current IPs (may be multiple if on both mobile and WiFi)
    List<String> currentIps;
    if (system.isAndroid && isRunning) {
      // Android VPN running: use native detection
      currentIps = await _getNativeLocalIpAddresses();
    } else {
      // Android VPN stopped or other platforms
      final ip = await _getLocalIpAddress();
      currentIps = ip != null ? [ip] : [];
    }

    if (currentIps.isEmpty) {
      commonPrint.log('Smart Auto Stop: No legitimate IP found. Skipping.');
      return;
    }

    // Dedup check to avoid repeated actions on same IP
    final ipsKey = currentIps.join(',');
    if (ipsKey == _lastCheckedIp &&
        ((isRunning && !isSmartStopped) || (!isRunning && isSmartStopped))) {
      // State is stable matching current IP, skip
      return;
    }
    _lastCheckedIp = ipsKey;

    // 3. Match Logic - check ALL IPs against rules
    bool shouldStop = false;
    for (final ip in currentIps) {
      if (NetworkMatcher.matchAny(ip, networks)) {
        shouldStop = true;
        break;
      }
    }

    commonPrint.log(
      'SmartAutoStop: IPs=$currentIps, RuleMatch=$shouldStop, Running=$isRunning, SmartStopped=$isSmartStopped',
    );

    if (shouldStop) {
      // Rule matched: VPN should be STOPPED
      if (isRunning && !isSmartStopped) {
        // Only mark as smart-stopped if we are currently running normally
        ref.read(isSmartStoppedProvider.notifier).set(true);
        commonPrint.log('Smart Auto Stop: Stopping VPN...');
        await _stopVpn();
      }
    } else {
      // Rule NOT matched: VPN should be RUNNING (if it was smart-stopped)
      if (!isRunning && isSmartStopped) {
        ref.read(isSmartStoppedProvider.notifier).set(false);
        commonPrint.log('Smart Auto Stop: Restarting VPN...');
        await _restartVpn();
      }
    }
  }

  Future<List<String>> _getNativeLocalIpAddresses() async {
    try {
      final serviceInstance = service;
      if (serviceInstance != null) {
        final ips = await serviceInstance.getLocalIpAddresses();
        return ips;
      }
    } catch (e) {
      commonPrint.log('Smart Auto Stop: Native IP error: $e');
    }
    final ip = await _getLocalIpAddress();
    return ip != null ? [ip] : [];
  }

  Future<String?> _getLocalIpAddress() async {
    return await utils.getLocalIpAddress();
  }

  Future<void> _stopVpn() async {
    if (system.isAndroid) {
      // Android: Enable smart-stop mode (Blank notification)
      // This keeps the service alive but stops the VPN logic
      await service?.setSmartStopped(true);
      await service?.smartStop();

      // Update Dart state to look "stopped"
      globalState.startTime = null;
      clashCore.resetTraffic();
      ref.read(trafficsProvider.notifier).clear();
      ref.read(totalTrafficProvider.notifier).value = Traffic();
      ref.read(runTimeProvider.notifier).value = null;
    } else {
      // Desktop: Full stop
      await globalState.appController.updateStatus(false);
    }
  }

  Future<void> _restartVpn() async {
    if (system.isAndroid) {
      // Android: Resume from smart-stop mode
      await service?.setSmartStopped(false);
      await service?.smartResume();

      globalState.startTime = DateTime.now();
      ref.read(runTimeProvider.notifier).value = 0;
      globalState.appController.addCheckIpNumDebounce();
    } else {
      // Desktop: Full start
      await globalState.appController.updateStatus(true);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
