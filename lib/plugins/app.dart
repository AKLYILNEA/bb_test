import 'dart:async';

import 'package:bett_box/common/app_localizations.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class App {
  static App? _instance;
  late MethodChannel methodChannel;
  Function()? onExit;

  App._internal() {
    methodChannel = const MethodChannel('app');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'exit':
          await onExit?.call();
        case 'getText':
          try {
            return Intl.message(call.arguments as String);
          } catch (_) {
            return '';
          }
        default:
          throw MissingPluginException();
      }
    });
  }

  factory App() {
    _instance ??= App._internal();
    return _instance!;
  }

  Future<bool?> moveTaskToBack() async {
    return await methodChannel.invokeMethod<bool>('moveTaskToBack');
  }

  Future<List<Package>> getPackages({bool forceRefresh = false}) async {
    final packagesRaw =
        await methodChannel.invokeMethod<List<dynamic>>('getPackages', {
          'forceRefresh': forceRefresh,
        }) ??
        const <dynamic>[];
    return packagesRaw
        .map((e) => Package.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  /// 检查是否有应用列表权限 (Android 11+)
  Future<bool> hasPackageListPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasPackageListPermission',
    );
    return result ?? true; // 默认返回 true (Android 10 及以下不需要此权限)
  }

  Future<bool> hasCameraPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasCameraPermission',
    );
    return result ?? true;
  }

  /// 请求应用列表权限 (打开系统设置页面)
  Future<void> requestPackageListPermission() async {
    await methodChannel.invokeMethod<void>('requestPackageListPermission');
  }

  Future<void> openAppSettings() async {
    await methodChannel.invokeMethod<void>('openAppSettings');
  }

  Future<List<String>> getChinaPackageNames() async {
    final packageNamesRaw =
        await methodChannel.invokeMethod<List<dynamic>>(
          'getChinaPackageNames',
        ) ??
        const <dynamic>[];
    return packageNamesRaw.map((e) => e.toString()).toList();
  }

  Future<bool> openFile(String path) async {
    return await methodChannel.invokeMethod<bool>('openFile', {'path': path}) ??
        false;
  }

  /// 获取应用图标（使用磁盘缓存，不使用内存缓存）
  /// [packageName] 应用包名
  /// [forceRefresh] 是否强制刷新（手动刷新时使用）
  Future<Uint8List?> getPackageIcon(
    String packageName, {
    bool forceRefresh = false,
  }) async {
    return await methodChannel.invokeMethod<Uint8List>('getPackageIcon', {
      'packageName': packageName,
      'forceRefresh': forceRefresh,
    });
  }

  Future<bool?> tip(String? message) async {
    return await methodChannel.invokeMethod<bool>('tip', {
      'message': '$message',
    });
  }

  Future<bool?> initShortcuts() async {
    return await methodChannel.invokeMethod<bool>(
      'initShortcuts',
      appLocalizations.toggle,
    );
  }

  Future<bool?> updateExcludeFromRecents(bool value) async {
    return await methodChannel.invokeMethod<bool>('updateExcludeFromRecents', {
      'value': value,
    });
  }

  /// 获取当前应用APK的最后更新时间（毫秒时间戳）
  /// 用于检测APK是否被重新安装（包括升级、降级、覆盖安装等）
  Future<int> getSelfLastUpdateTime() async {
    final result = await methodChannel.invokeMethod<int>(
      'getSelfLastUpdateTime',
    );
    return result ?? 0;
  }

  /// 检查应用是否在电池优化白名单中
  Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await methodChannel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return result ?? false;
  }

  /// 请求将应用加入电池优化白名单
  Future<void> requestIgnoreBatteryOptimizations() async {
    await methodChannel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
  }

  /// 设置启动图标（浅色/深色）
  /// [useLightIcon] true: 使用浅色图标, false: 使用深色图标
  Future<bool> setLauncherIcon(bool useLightIcon) async {
    final result = await methodChannel.invokeMethod<bool>('setLauncherIcon', {
      'useLightIcon': useLightIcon,
    });
    return result ?? false;
  }

  /// 检测是否为 Android TV
  Future<bool> isAndroidTV() async {
    final result = await methodChannel.invokeMethod<bool>('isAndroidTV');
    return result ?? false;
  }
}

final app = App();
