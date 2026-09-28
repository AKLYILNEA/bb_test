import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCurrentProfileDialog() async {
  await globalState.showCommonDialog<void>(
    child: const CurrentProfileDialog(),
  );
}

class CurrentProfileDialog extends ConsumerWidget {
  const CurrentProfileDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final profile = ref.watch(currentProfileProvider);

    return CommonDialog(
      title: appLocalizations.currentProfile,
      overrideScroll: true,
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
        children: [
          profiles.isEmpty
              ? const _EmptySubscriptionPanel()
              : _SubscriptionPanel(profile: profile),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: profiles.isEmpty
                  ? SizedBox(
                      height: 72,
                      child: Center(
                        child: EmojiText(
                          appLocalizations.nullProfileDesc,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodySmall?.toLight,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in profiles)
                          _ProfileRadioItem(
                            profile: item,
                            currentProfileId: currentProfileId,
                            onChanged: (value) {
                              ref
                                  .read(currentProfileIdProvider.notifier)
                                  .value = value;
                            },
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRadioItem extends StatelessWidget {
  final Profile profile;
  final String? currentProfileId;
  final ValueChanged<String?> onChanged;

  const _ProfileRadioItem({
    required this.profile,
    required this.currentProfileId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final expireDesc = profile.subscriptionInfo?.expireDesc;
    return ListItem<String>.radio(
      key: ValueKey(profile.id),
      title: EmojiText(
        profile.label ?? profile.id,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium,
      ),
      subtitle: expireDesc == null || expireDesc.isEmpty
          ? null
          : EmojiText(
              expireDesc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.toLight,
            ),
      delegate: RadioDelegate<String>(
        value: profile.id,
        groupValue: currentProfileId ?? '',
        onChanged: onChanged,
      ),
    );
  }
}

class _EmptySubscriptionPanel extends StatelessWidget {
  const _EmptySubscriptionPanel();

  @override
  Widget build(BuildContext context) {
    return _PanelContainer(
      child: EmojiText(
        appLocalizations.notAcquired,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.toLight,
      ),
    );
  }
}

class _SubscriptionPanel extends StatelessWidget {
  final Profile? profile;

  const _SubscriptionPanel({this.profile});

  String _buildTrafficText(SubscriptionInfo? info) {
    if (info == null) {
      return appLocalizations.notAcquired;
    }
    final use = info.upload + info.download;
    final total = info.total;
    if (use == 0 && total == 0) {
      return appLocalizations.notAcquired;
    }
    final useShow = TrafficValue(value: use).show;
    if (total <= 0) {
      return useShow;
    }
    return '$useShow / ${TrafficValue(value: total).show}';
  }

  @override
  Widget build(BuildContext context) {
    final info = profile?.subscriptionInfo;
    final lastUpdateDate = profile?.lastUpdateDate;
    final hasUsageBar =
        info != null && (info.upload + info.download > 0 || info.total > 0);
    final lineStyle = context.textTheme.bodySmall;

    return _PanelContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmojiText(
            '${appLocalizations.expirationTime} · '
            '${info?.expireDesc ?? appLocalizations.notAcquired}',
            textAlign: TextAlign.center,
            style: lineStyle,
          ),
          const SizedBox(height: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmojiText(
                '${appLocalizations.trafficUsage} · '
                '${_buildTrafficText(info)}',
                textAlign: TextAlign.center,
                style: lineStyle,
              ),
              if (hasUsageBar)
                SubscriptionInfoView(subscriptionInfo: info)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EmojiText(
                    appLocalizations.noUsageData,
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelSmall?.toLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          EmojiText(
            '${appLocalizations.updateTime} · '
            '${lastUpdateDate?.lastUpdateTimeDesc ?? appLocalizations.notAcquired}',
            textAlign: TextAlign.center,
            style: lineStyle,
          ),
        ],
      ),
    );
  }
}

class _PanelContainer extends StatelessWidget {
  final Widget child;

  const _PanelContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: child,
    );
  }
}
