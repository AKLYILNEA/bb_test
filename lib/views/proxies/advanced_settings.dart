import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesAdvancedSettings extends ConsumerWidget {
  const ProxiesAdvancedSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: generateSection(
        items: [
          const _NodeExclusionItem(),
          const _ConcurrencyLimitItem(),
          const _DelayAnimationItem(),
        ],
      ),
    );
  }
}

class _NodeExclusionItem extends ConsumerWidget {
  const _NodeExclusionItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeExcludeFilter = globalState.config.nodeExcludeFilter;

    return ListItem.input(
      leading: const Icon(Icons.filter_alt_outlined),
      title: Text(appLocalizations.nodeExclusion),
      subtitle: Text(
        nodeExcludeFilter.isEmpty
            ? appLocalizations.nodeExclusionPlaceholder
            : nodeExcludeFilter,
      ),
      delegate: InputDelegate(
        title: appLocalizations.nodeExclusion,
        value: nodeExcludeFilter,
        onChanged: (String? value) {
          if (value == null) return;
          final filter = value.trim();
          globalState.config = globalState.config.copyWith(
            nodeExcludeFilter: filter,
          );
          globalState.appController.applyProfileDebounce();
        },
      ),
    );
  }
}

class _ConcurrencyLimitItem extends ConsumerWidget {
  const _ConcurrencyLimitItem();

  static const _options = [1, 4, 8, 16, 32, 64];

  String _getDisplayText(int value, BuildContext context) {
    if (value == 64) {
      return '$value (${appLocalizations.notRecommended})';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concurrencyLimit = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.concurrencyLimit),
    );

    return ListItem<int>.options(
      leading: const Icon(Icons.speed),
      title: Text(appLocalizations.concurrencyLimit),
      subtitle: Text(appLocalizations.concurrencyLimitDesc),
      delegate: OptionsDelegate(
        title: appLocalizations.concurrencyLimit,
        options: _options,
        value: concurrencyLimit,
        textBuilder: (value) => _getDisplayText(value, context),
        onChanged: (value) {
          if (value != null) {
            ref.read(proxiesStyleSettingProvider.notifier).updateState(
                  (state) => state.copyWith(concurrencyLimit: value),
                );
          }
        },
      ),
    );
  }
}

class _DelayAnimationItem extends ConsumerWidget {
  const _DelayAnimationItem();

  String _getTextForDelayAnimation(DelayAnimationType type) {
    return switch (type) {
      DelayAnimationType.none => appLocalizations.noAnimation,
      DelayAnimationType.rotatingCircle => appLocalizations.rotatingCircle,
      DelayAnimationType.pulse => appLocalizations.pulse,
      DelayAnimationType.spinningLines => appLocalizations.spinningLines,
      DelayAnimationType.threeInOut => appLocalizations.threeInOut,
      DelayAnimationType.threeBounce => appLocalizations.threeBounce,
      DelayAnimationType.circle => appLocalizations.circle,
      DelayAnimationType.fadingCircle => appLocalizations.fadingCircle,
      DelayAnimationType.fadingFour => appLocalizations.fadingFour,
      DelayAnimationType.wave => appLocalizations.wave,
      DelayAnimationType.doubleBounce => appLocalizations.doubleBounce,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delayAnimation = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.delayAnimation),
    );

    return ListItem<DelayAnimationType>.options(
      leading: const Icon(Icons.animation),
      title: Text(appLocalizations.delayAnimation),
      subtitle: Text(appLocalizations.delayAnimationDesc),
      delegate: OptionsDelegate(
        title: appLocalizations.delayAnimation,
        options: DelayAnimationType.values,
        value: delayAnimation,
        textBuilder: (value) => _getTextForDelayAnimation(value),
        onChanged: (value) {
          if (value != null) {
            ref.read(proxiesStyleSettingProvider.notifier).updateState(
                  (state) => state.copyWith(delayAnimation: value),
                );
          }
        },
      ),
    );
  }
}
