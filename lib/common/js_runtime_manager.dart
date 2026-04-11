import 'dart:async';

import 'package:flutter_js/flutter_js.dart';
import 'package:synchronized/synchronized.dart';

class JavaScriptRuntimeManager {
  static JavascriptRuntime? _instance;
  static final Lock _lock = Lock();
  static int _activeCount = 0;
  static int _totalExecuteCount = 0;
  static bool _isDisposing = false;
  static const int _cleanupThreshold = 1;

  static Future<T> execute<T>(
    Future<T> Function(JavascriptRuntime runtime) task,
  ) async {
    final runtime = await _acquire();
    try {
      return await task(runtime);
    } finally {
      await _release();
    }
  }

  static Future<JavascriptRuntime> _acquire() async {
    return _lock.synchronized(() async {
      while (_isDisposing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (_totalExecuteCount >= _cleanupThreshold &&
          _activeCount == 0 &&
          _instance != null) {
        _isDisposing = true;
        try {
          _instance!.dispose();
        } catch (_) {}
        _instance = null;
        _totalExecuteCount = 0;
        _isDisposing = false;
      }

      _activeCount++;
      _totalExecuteCount++;
      _instance ??= getJavascriptRuntime();
      return _instance!;
    });
  }

  static Future<void> _release() async {
    await _lock.synchronized(() async {
      _activeCount--;
      if (_activeCount <= 0 && _instance != null) {
        _isDisposing = true;
        try {
          _instance!.dispose();
        } catch (_) {}
        _instance = null;
        _activeCount = 0;
        _isDisposing = false;
      }
    });
  }

  static Future<void> dispose() async {
    return _lock.synchronized(() async {
      if (_instance != null) {
        try {
          _instance!.dispose();
        } catch (_) {}
        _instance = null;
      }
      _activeCount = 0;
      _totalExecuteCount = 0;
      _isDisposing = false;
    });
  }
}
