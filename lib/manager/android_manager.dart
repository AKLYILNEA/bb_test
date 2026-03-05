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
  int? _sdkInt;

  @override
  void initState() {
    super.initState();
    
    // Get Android version
    system.version.then((version) {
      if (mounted) {
        setState(() {
          _sdkInt = version;
        });
        
        // Force disable hidden for Android 13+ (SDK 33+)
        if (version >= 33) {
          final currentHidden = ref.read(appSettingProvider).hidden;
          if (currentHidden) {
            ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(hidden: false),
            );
          }
        }
      }
    });
    
    ref.listenManual(appSettingProvider.select((state) => state.hidden), (
      prev,
      next,
    ) {
      // Block hidden feature for Android 13+ (SDK 33+)
      if (_sdkInt != null && _sdkInt! >= 33 && next) {
        return;
      }
      app.updateExcludeFromRecents(next);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
