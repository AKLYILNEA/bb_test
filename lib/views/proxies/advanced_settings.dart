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
          const _HealthCheckTimeoutItem(),
          const _DelayAnimationItem(),
        ],
      ),
    );
  }
}

class _NodeExclusionItem extends ConsumerWidget {
  const _NodeExclusionItem();

  String? _validateRegex(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      RegExp(value.trim());
      return null;
    } catch (e) {
      return appLocalizations.formatError;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeExcludeFilter = globalState.config.nodeExcludeFilter;

    return ListItem.input(
      leading: const Icon(Icons.filter_alt_outlined),
      title: Text(appLocalizations.nodeExclusion),
      subtitle: Text(appLocalizations.nodeExclusionDesc),
      delegate: InputDelegate(
        title: appLocalizations.nodeExclusion,
        value: nodeExcludeFilter,
        hintText: appLocalizations.nodeExclusionPlaceholder,
        validator: _validateRegex,
        onChanged: (String? value) {
          // Only update if value is not null (validation passed)
          if (value != null) {
            final filter = value.trim();
            globalState.config = globalState.config.copyWith(
              nodeExcludeFilter: filter,
            );
            globalState.appController.applyProfileDebounce();
          }
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

class _HealthCheckTimeoutItem extends ConsumerWidget {
  const _HealthCheckTimeoutItem();

  static const _options = [1000, 2000, 3000, 5000, 8000];

  String _getDisplayText(int value) {
    return '${value ~/ 1000}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeout = globalState.config.healthCheckTimeout;

    return ListItem<int>.options(
      leading: const Icon(Icons.timer_outlined),
      title: Text(appLocalizations.healthCheckTimeout),
      subtitle: Text(appLocalizations.healthCheckTimeoutDesc),
      delegate: OptionsDelegate(
        title: appLocalizations.healthCheckTimeout,
        options: _options,
        value: timeout,
        textBuilder: _getDisplayText,
        onChanged: (value) {
          if (value != null) {
            globalState.config = globalState.config.copyWith(
              healthCheckTimeout: value,
            );
            globalState.appController.applyProfileDebounce();
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
