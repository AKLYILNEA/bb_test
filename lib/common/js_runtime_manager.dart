import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';

class JavaScriptRuntimeManager {
  static Future<Map<String, dynamic>> evaluateScript(
    String scriptContent,
    Map<String, dynamic> config,
  ) async {
    final runtime = getJavascriptRuntime();
    try {
      final configJs = json.encode(config);
      final res = await runtime.evaluateAsync('''
        $scriptContent
        main($configJs)
      ''');
      if (res.isError) {
        throw res.stringResult;
      }
      final value = switch (res.rawResult is ffi.Pointer) {
        true => runtime.convertValue<Map<String, dynamic>>(res),
        false => Map<String, dynamic>.from(res.rawResult),
      };
      return value ?? config;
    } finally {
      if (!Platform.isMacOS) {
        runtime.dispose();
      }
    }
  }
}
