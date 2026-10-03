import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/scripts.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

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

  Future<void> _handleSelectScript(
    BuildContext context,
    WidgetRef ref,
    Profile currentProfile,
    ScriptProps scriptProps,
  ) async {
    final scripts = scriptProps.scripts;
    final currentScriptId =
        currentProfile.useScriptOverride ? currentProfile.scriptId : null;

    final selected = await globalState.showCommonDialog<String?>(
      child: OptionsDialog<String?>(
        title: '${currentProfile.label ?? currentProfile.id} - ${appLocalizations.script}',
        options: [null, ...scripts.map((s) => s.id)],
        value: currentScriptId,
        textBuilder: (val) {
          if (val == null) {
            return appLocalizations.none;
          }
          final match = scripts.where((s) => s.id == val).firstOrNull;
          return match?.label ?? val;
        },
      ),
    );

    if (selected == currentScriptId) return;

    if (selected == null) {
      ref.read(profilesProvider.notifier).updateProfile(
        currentProfile.id,
        (p) => p.copyWith(useScriptOverride: false, scriptId: null),
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

    final String displayText;
    if (currentProfile == null) {
      displayText = appLocalizations.none;
    } else if (isEnabled && effectiveScript != null) {
      displayText = effectiveScript.label;
    } else {
      displayText = appLocalizations.none;
    }

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: appLocalizations.script,
          iconData: FluentIcons.javascript_24_regular,
        ),
        onPressed: () {
          if (currentProfile != null) {
            _handleSelectScript(context, ref, currentProfile, scriptProps);
          } else {
            _openScripts(context);
          }
        },
        onLongPress: () {
          _openScripts(context);
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 12),
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
                    style: isEnabled
                        ? Theme.of(context).textTheme.titleSmall?.adjustSize(-2).copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : Theme.of(context).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Icon(
                FluentIcons.chevron_up_down_24_regular,
                size: 16,
                color: context.colorScheme.outline.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
