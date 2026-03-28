import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidManager extends ConsumerStatefulWidget {
  final Widget child;

  const AndroidManager({super.key, required this.child});

  @override
  ConsumerState<AndroidManager> createState() => _AndroidContainerState();
}

class _AndroidContainerState extends ConsumerState<AndroidManager> {
  Timer? _retryTimer;

  Future<void> _updateExcludeFromRecents(bool value, {int retryCount = 0}) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);

    try {
      final success = await app.updateExcludeFromRecents(value);
      if (success != true && retryCount < maxRetries) {
        _retryTimer?.cancel();
        _retryTimer = Timer(retryDelay, () {
          _updateExcludeFromRecents(value, retryCount: retryCount + 1);
        });
      }
    } catch (e) {
      commonPrint.log('updateExcludeFromRecents error: $e');
      if (retryCount < maxRetries) {
        _retryTimer?.cancel();
        _retryTimer = Timer(retryDelay, () {
          _updateExcludeFromRecents(value, retryCount: retryCount + 1);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    ref.listenManual(appSettingProvider.select((state) => state.hidden), (
      prev,
      next,
    ) {
      _updateExcludeFromRecents(next);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}