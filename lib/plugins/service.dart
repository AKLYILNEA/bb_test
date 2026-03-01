import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:bett_box/common/system.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/services.dart';

import '../clash/lib.dart';

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;
  ReceivePort? receiver;

  Service._internal() {
    methodChannel = const MethodChannel('service');
  }

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Future<bool?> init() async {
    return await methodChannel.invokeMethod<bool>('init');
  }

  Future<bool?> destroy() async {
    return await methodChannel.invokeMethod<bool>('destroy');
  }

  Future<bool?> startVpn() async {
    final options = await clashLib?.getAndroidVpnOptions();
    return await methodChannel.invokeMethod<bool>('startVpn', {
      'data': json.encode(options),
    });
  }

  Future<bool?> stopVpn() async {
    return await methodChannel.invokeMethod<bool>('stopVpn');
  }

  /// Smart stop: Stop VPN but keep foreground service running.
  /// Used by Smart Auto Stop feature.
  Future<bool?> smartStop() async {
    return await methodChannel.invokeMethod<bool>('smartStop');
  }

  /// Smart resume: Resume VPN from smart-stopped state.
  Future<bool?> smartResume() async {
    final options = await clashLib?.getAndroidVpnOptions();
    return await methodChannel.invokeMethod<bool>('smartResume', {
      'data': json.encode(options),
    });
  }

  /// Set the smart-stopped state in native code.
  Future<void> setSmartStopped(bool value) async {
    await methodChannel.invokeMethod<bool>('setSmartStopped', {'value': value});
  }

  /// Check if VPN was stopped by smart auto stop feature.
  Future<bool> isSmartStopped() async {
    return await methodChannel.invokeMethod<bool>('isSmartStopped') ?? false;
  }

  /// Get local IP addresses from native Android code.
  /// More reliable than connectivity_plus when VPN is running.
  Future<List<String>> getLocalIpAddresses() async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'getLocalIpAddresses',
    );
    return result?.cast<String>() ?? [];
  }

  /// Set quick response enabled state in native code.
  Future<bool?> setQuickResponse(bool enabled) async {
    return await methodChannel.invokeMethod<bool>('setQuickResponse', {
      'enabled': enabled,
    });
  }
}

Service? get service =>
    system.isAndroid && !globalState.isService ? Service() : null;
