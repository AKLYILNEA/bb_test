import 'dart:async';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showCoreStatusDialog(BuildContext context) async {
  await globalState.showCommonDialog<void>(
    child: const CoreStatusDialog(),
  );
}

class CoreStatusDialog extends StatefulWidget {
  const CoreStatusDialog({super.key});

  @override
  State<CoreStatusDialog> createState() => _CoreStatusDialogState();
}

class _CoreStatusDialogState extends State<CoreStatusDialog> {
  CoreStatus? _status;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await clashCore.getCoreStatus();
      if (!mounted) return;
      if (status != null) {
        setState(() {
          _status = status;
        });
      }
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    return TrafficValue(value: bytes).shortShow;
  }

  String _formatCount(int count) {
    return NumberFormat.decimalPattern().format(count);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        '[ $title ]',
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '• $label:',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final inUseText = status != null ? _formatBytes(status.inUse) : '-';
    final reclaimableText =
        status != null ? _formatBytes(status.reclaimable) : '-';
    final goroutinesText =
        status != null ? _formatCount(status.goroutines) : '-';
    final heapObjectsText =
        status != null ? _formatCount(status.heapObjects) : '-';
    final rulesText = status != null ? _formatCount(status.rules) : '-';
    final proxiesText = status != null ? _formatCount(status.proxies) : '-';
    final proxyGroupsText =
        status != null ? _formatCount(status.proxyGroups) : '-';
    final ruleProvidersText =
        status != null ? _formatCount(status.ruleProviders) : '-';
    final proxyProvidersText =
        status != null ? _formatCount(status.proxyProviders) : '-';
    final geodataUseText = status?.geodataUse ?? '-';

    return CommonDialog(
      title: appLocalizations.coreStatus,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(appLocalizations.memoryAndRuntime),
          _buildMetricRow(appLocalizations.allocatedMemory, inUseText),
          _buildMetricRow(appLocalizations.reclaimableMemory, reclaimableText),
          _buildMetricRow(appLocalizations.activeGoroutines, goroutinesText),
          _buildMetricRow(appLocalizations.heapObjects, heapObjectsText),
          _buildSectionHeader(appLocalizations.profileAndRules),
          _buildMetricRow(appLocalizations.rulesCount, rulesText),
          _buildMetricRow(appLocalizations.proxiesCount, proxiesText),
          _buildMetricRow(appLocalizations.proxyGroupsCount, proxyGroupsText),
          if ((status?.ruleProviders ?? 0) > 0)
            _buildMetricRow(
              appLocalizations.ruleProvidersCount,
              ruleProvidersText,
            ),
          if ((status?.proxyProviders ?? 0) > 0)
            _buildMetricRow(
              appLocalizations.proxyProvidersCount,
              proxyProvidersText,
            ),
          _buildMetricRow(appLocalizations.geodataUse, geodataUseText),
        ],
      ),
    );
  }
}
