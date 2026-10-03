import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/scripts.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ScriptOverride extends StatelessWidget {
  const ScriptOverride({super.key});

  Future<void> _openScripts(BuildContext context) async {
    await showExtend(
      context,
      builder: (_, type) {
        return const ScriptsView();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () => _openScripts(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InfoHeader(
              padding: baseInfoEdgeInsets.copyWith(bottom: 0),
              info: Info(
                label: appLocalizations.script,
                iconData: FluentIcons.javascript_24_regular,
              ),
            ),
            Container(
              padding: baseInfoEdgeInsets.copyWith(top: 0),
              child: SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        appLocalizations.scriptDesc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium?.toLight.adjustSize(
                          -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
