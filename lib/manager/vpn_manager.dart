import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/state.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VpnManager extends ConsumerStatefulWidget {
  final Widget child;

  const VpnManager({super.key, required this.child});

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(vpnStateProvider, (prev, next) {
      showTip();
    });
  }

  void showTip() {
    debouncer.call(FunctionTag.vpnTip, () {
      if (ref.read(runTimeProvider.notifier).isStart) {
        globalState.showNotifier(
          appLocalizations.vpnTip,
          onAction: () async {
            await globalState.appController.updateStatus(false);
            await Future.delayed(const Duration(milliseconds: 500));
            await globalState.appController.updateStatus(true);
          },
          actionLabel: appLocalizations.restart,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
