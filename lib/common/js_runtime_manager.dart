import 'dart:async';
import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

class JavaScriptRuntimeManager {
  static Future<Map<String, dynamic>> evaluateScript(
    String scriptContent,
    Map<String, dynamic> config,
  ) async {
    final engine = IsolateQjs();
    try {
      final configJs = json.encode(config);
      final res = await engine.evaluate('''
        (async function() {
          $scriptContent
          return await main($configJs);
        })();
      ''');
      
      if (res is Map) {
        return _deepCastMap(res);
      }
      return config;
    } catch (e) {
      throw 'JS Script Error: $e';
    } finally {
      engine.close();
    }
  }

  static Map<String, dynamic> _deepCastMap(Map dynamicMap) {
    return dynamicMap.map<String, dynamic>((key, value) {
      return MapEntry(key.toString(), _deepCastValue(value));
    });
  }

  static dynamic _deepCastValue(dynamic value) {
    if (value is Map) {
      return _deepCastMap(value);
    } else if (value is List) {
      return value.map((e) => _deepCastValue(e)).toList();
    }
    return value;
  }
}
