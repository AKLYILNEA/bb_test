import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesAdvancedSettings extends ConsumerWidget {
  const ProxiesAdvancedSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ConcurrencyLimitItem(),
      ],
    );
  }
}

class _ConcurrencyLimitItem extends ConsumerWidget {
  const _ConcurrencyLimitItem();

  static const _options = [1, 4, 8, 16, 32, 64];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concurrencyLimit = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.concurrencyLimit),
    );

    return ListItem(
      title: Text(appLocalizations.concurrencyLimit),
      subtitle: Text(appLocalizations.concurrencyLimitDesc),
      trailing: Text('$concurrencyLimit'),
      onTap: () async {
        final selected = await showSheet<int>(
          context: context,
          builder: (_, type) {
            return AdaptiveSheetScaffold(
              type: type,
              title: appLocalizations.concurrencyLimit,
              body: ListView.builder(
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final value = _options[index];
                  final isNotRecommended = value == 64;

                  return ListItem.radio(
                    padding: const EdgeInsets.only(left: 12, right: 16),
                    title: Row(
                      children: [
                        Text('$value'),
                        if (isNotRecommended) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(${appLocalizations.notRecommended})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    delegate: RadioDelegate(
                      value: value,
                      groupValue: concurrencyLimit,
                      onChanged: (v) {
                        Navigator.of(context, rootNavigator: true).pop(v);
                      },
                    ),
                  );
                },
              ),
            );
          },
        );

        if (selected != null && selected != concurrencyLimit) {
          ref.read(proxiesStyleSettingProvider.notifier).updateState(
                (state) => state.copyWith(concurrencyLimit: selected),
              );
        }
      },
    );
  }
}
