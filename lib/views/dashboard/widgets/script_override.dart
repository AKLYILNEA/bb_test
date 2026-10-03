import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/scripts.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

///
///
class ScriptOverride extends ConsumerWidget {
  const ScriptOverride({super.key});

  Future<void> _openScripts(BuildContext context) async {
    await showExtend(
      context,
      builder: (_, type) {
        return const ScriptsView();
      },
    );
  }

  Future<void> _handleToggle(
    WidgetRef ref,
    Profile currentProfile,
    ScriptProps scriptProps,
    bool enable,
  ) async {
    if (enable) {
      if (currentProfile.scriptId == null &&
          scriptProps.currentScript == null &&
          scriptProps.scripts.isNotEmpty) {
        ref.read(scriptStateProvider.notifier).setId(scriptProps.scripts.first.id);
      }
      ref.read(profilesProvider.notifier).updateProfile(
        currentProfile.id,
        (p) => p.copyWith(useScriptOverride: true),
      );
    } else {
      ref.read(profilesProvider.notifier).updateProfile(
        currentProfile.id,
        (p) => p.copyWith(useScriptOverride: false),
      );
    }
    try {
      await globalState.appController.applyProfile(silence: true);
    } catch (e) {
      commonPrint.log('Apply profile after script override toggle failed: $e');
    }
  }

  Future<void> _handleSelectScript(
    BuildContext context,
    WidgetRef ref,
    Profile currentProfile,
    ScriptProps scriptProps,
  ) async {
    final currentSelected = !currentProfile.useScriptOverride
        ? '__disabled__'
        : (currentProfile.scriptId ?? '__follow_global__');
    final options = [
      '__follow_global__',
      ...scriptProps.scripts.map((s) => s.id),
      '__disabled__',
    ];
    final selected = await globalState.showCommonDialog<String>(
      child: OptionsDialog<String>(
        title:
            '${currentProfile.label ?? currentProfile.id} - ${appLocalizations.script}',
        options: options,
        value: currentSelected,
        textBuilder: (val) {
          if (val == '__disabled__') {
            return appLocalizations.noScriptAssigned;
          }
          if (val == '__follow_global__') {
            final defName =
                scriptProps.currentScript?.label ?? appLocalizations.none;
            return '${appLocalizations.followGlobal} ($defName)';
          }
          final match =
              scriptProps.scripts.where((s) => s.id == val).firstOrNull;
          return match?.label ?? val;
        },
      ),
    );
    if (selected == null) return;
    if (selected == '__disabled__') {
      ref.read(profilesProvider.notifier).updateProfile(
        currentProfile.id,
        (p) => p.copyWith(useScriptOverride: false),
      );
    } else if (selected == '__follow_global__') {
      ref.read(profilesProvider.notifier).updateProfile(
        currentProfile.id,
        (p) => p.copyWith(useScriptOverride: true, scriptId: null),
      );
    } else {
      ref.read(profilesProvider.notifier).updateProfile(
        currentProfile.id,
        (p) => p.copyWith(useScriptOverride: true, scriptId: selected),
      );
    }
    await globalState.appController.applyProfile(silence: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfile = ref.watch(currentProfileProvider);
    final scriptProps = ref.watch(scriptStateProvider);
    final effectiveScript = currentProfile?.getEffectiveScript(scriptProps);
    final isEnabled =
        currentProfile?.useScriptOverride == true && effectiveScript != null;
    final hasScripts = scriptProps.scripts.isNotEmpty;

    final String displayText;
    if (currentProfile == null) {
      displayText = appLocalizations.override;
    } else if (isEnabled && effectiveScript != null) {
      displayText = effectiveScript.label;
    } else {
      displayText = appLocalizations.override;
    }

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: appLocalizations.script,
          iconData: FluentIcons.javascript_24_regular,
        ),
        onPressed: () {
          _openScripts(context);
        },
        onLongPress: currentProfile != null && hasScripts
            ? () => _handleSelectScript(context, ref, currentProfile, scriptProps)
            : null,
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: EmojiText(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -3),
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: isEnabled,
                  onChanged: currentProfile != null && hasScripts
                      ? (value) {
                          _handleToggle(
                            ref,
                            currentProfile,
                            scriptProps,
                            value,
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
