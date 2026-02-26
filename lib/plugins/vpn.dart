import 'dart:async';
import 'dart:convert';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class VpnListener {
  void onDnsChanged(String dns) {}
}

class Vpn {
  static Vpn? _instance;
  late MethodChannel methodChannel;
  FutureOr<String> Function()? handleGetStartForegroundParams;

  Vpn._internal() {
    methodChannel = const MethodChannel('vpn');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'gc':
          clashCore.requestGc();
        case 'closeConnections':
          clashCore.closeConnections();
        case 'getStartForegroundParams':
          if (handleGetStartForegroundParams != null) {
            return await handleGetStartForegroundParams!();
          }
          return '';
        case 'status':
          return clashLibHandler?.getRunTime() != null;
        default:
          for (final VpnListener listener in _listeners) {
            switch (call.method) {
              case 'dnsChanged':
                final dns = call.arguments as String;
                listener.onDnsChanged(dns);
            }
          }
      }
    });
  }

  factory Vpn() {
    _instance ??= Vpn._internal();
    return _instance!;
  }

  final ObserverList<VpnListener> _listeners = ObserverList<VpnListener>();

  Future<bool?> start(AndroidVpnOptions options) async {
    return await methodChannel.invokeMethod<bool>('start', {
      'data': json.encode(options),
    });
  }

  Future<bool?> stop() async {
    return await methodChannel.invokeMethod<bool>('stop');
  }

  /// Get local IP addresses from native Android code.
  /// More reliable than connectivity_plus when VPN is running.
  Future<List<String>> getLocalIpAddresses() async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'getLocalIpAddresses',
    );
    return result?.cast<String>() ?? [];
  }

  /// Set the smart-stopped state in native code.
  /// This is used to show different notification content when smart-stopped.
  Future<void> setSmartStopped(bool value) async {
    await methodChannel.invokeMethod<bool>('setSmartStopped', {'value': value});
  }

  /// Check if VPN was stopped by smart auto stop feature.
  Future<bool> isSmartStopped() async {
    return await methodChannel.invokeMethod<bool>('isSmartStopped') ?? false;
  }

  /// Smart stop: Stop VPN but keep foreground service running.
  /// Used by Smart Auto Stop feature.
  Future<bool?> smartStop() async {
    return await methodChannel.invokeMethod<bool>('smartStop');
  }

  /// Smart resume: Resume VPN from smart-stopped state.
  Future<bool?> smartResume(AndroidVpnOptions options) async {
    return await methodChannel.invokeMethod<bool>('smartResume', {
      'data': json.encode(options),
    });
  }

  void addListener(VpnListener listener) {
    _listeners.add(listener);
  }

  void removeListener(VpnListener listener) {
    _listeners.remove(listener);
  }
}

Vpn? get vpn => globalState.isService ? Vpn() : null;
