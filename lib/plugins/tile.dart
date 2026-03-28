import 'dart:async';

import 'package:bett_box/common/system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class TileListener {
  void onStart() {}

  void onStop() {}

  void onDetached() {}

  void onReconnectIpc() {}
}

class Tile {
  final MethodChannel _channel = const MethodChannel('tile');

  Tile._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static final Tile instance = Tile._();

  final ObserverList<TileListener> _listeners = ObserverList<TileListener>();

  Future<void> _methodCallHandler(MethodCall call) async {
    for (final TileListener listener in _listeners) {
      switch (call.method) {
        case 'start':
          listener.onStart();
        case 'stop':
          listener.onStop();
        case 'detached':
          listener.onDetached();
        case 'reconnectIpc':
          listener.onReconnectIpc();
      }
    }
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(TileListener listener) {
    _listeners.add(listener);
  }

  void removeListener(TileListener listener) {
    _listeners.remove(listener);
  }
}

final tile = system.isAndroid ? Tile.instance : null;
