import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    // A filter left over from the last visit would hide rows and fake an
    // empty state, so the page always opens unfiltered.
    ref.read(logsSearchProvider.notifier).state = '';
    ref.read(logsKeywordsProvider.notifier).state = [];
    clashCore.startLog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      clashCore.stopLog();
    } else if (state == AppLifecycleState.resumed) {
      clashCore.startLog();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clashCore.stopLog();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(logsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(logsKeywordsProvider.notifier).state = keywords;
  }

  Future<void> _handleLogLevelSettings() async {
    final currentLogLevel = ref.read(
      patchClashConfigProvider.select((state) => state.logLevel),
    );

    final selectedLogLevel = await globalState.showCommonDialog<LogLevel>(
      child: OptionsDialog<LogLevel>(
        title: appLocalizations.logLevel,
        options: LogLevel.values,
        value: currentLogLevel,
        textBuilder: (logLevel) => logLevel.name,
      ),
    );

    if (selectedLogLevel != null && selectedLogLevel != currentLogLevel) {
      ref
          .read(patchClashConfigProvider.notifier)
          .updateState((state) => state.copyWith(logLevel: selectedLogLevel));
      globalState.appController.updateClashConfigDebounce();
    }
  }

  Future<void> _handleExport() async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        return await globalState.appController.exportLogs();
      },
      needLoading: true,
      title: appLocalizations.exportLogs,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
      cancelable: false,
    );
  }

  void _handleClearLogs() {
    ref.read(logsProvider.notifier).clearLogs();
    clashCore.clearLogs();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(filteredLogsProvider);
    return CommonScaffold(
      actions: [
        IconButton(
          onPressed: _handleLogLevelSettings,
          icon: const Icon(FluentIcons.settings_24_regular),
          tooltip: appLocalizations.logLevel,
        ),
        GestureDetector(
          onLongPress: _handleClearLogs,
          child: IconButton(
            onPressed: _handleExport,
            icon: const Icon(FluentIcons.save_edit_24_regular),
            tooltip: appLocalizations.export,
          ),
        ),
      ],
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      body: NullStatusSwitcher(
        isEmpty: logs.isEmpty,
        nullStatus: NullStatus(
          label: appLocalizations.nullTip(appLocalizations.logs),
          illustration: NullStatusIllustration.logs,
        ),
        child: CommonScrollBar(
          controller: _scrollController,
          child: ListView.builder(
            physics: const NextClampingScrollPhysics(),
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            itemBuilder: (context, index) {
              final log = logs[index];
              return LogItem(
                key: ValueKey(log.dateTime),
                log: log,
                onClick: (value) {
                  context.commonScaffoldState?.addKeyword(value);
                },
              );
            },
            itemCount: logs.length,
          ),
        ),
      ),
    );
  }
}

class _LogBody extends StatelessWidget {
  final LogPayload payload;
  final Color? errorColor;

  const _LogBody({required this.payload, this.errorColor});

  String get _sourceText => [
    payload.tag,
    if (payload.route case final route?) ...[route.source, route.sourceDetail],
  ].where((text) => text.isNotEmpty).join('  ·  ');

  @override
  Widget build(BuildContext context) {
    final styles = RecordTextStyles.of(context);
    final route = payload.route;
    if (route == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            payload.message,
            style: styles.primary,
          ),
          if (payload.tag.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                payload.tag,
                style: styles.muted,
              ),
            ),
        ],
      );
    }
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: route.destination,
            style: styles.primary?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (route.error.isNotEmpty)
            TextSpan(
              text: '\n${route.error}',
              style: styles.secondary?.copyWith(color: errorColor),
            ),
          const TextSpan(text: '\n'),
          if (route.rule.isNotEmpty) ...[
            TextSpan(
              text: route.rule,
              style: styles.secondary,
            ),
            TextSpan(
              text: ' \u2192 ',
              style: styles.muted?.toJetBrainsMono,
            ),
          ],
          TextSpan(
            text: route.proxy,
            style: styles.secondary?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_sourceText.isNotEmpty)
            TextSpan(
              text: '\n$_sourceText',
              style: styles.muted,
            ),
        ],
      ),
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;

  const LogItem({
    super.key,
    required this.log,
    this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final tone = switch (log.logLevel) {
      LogLevel.warning => RecordTone.warning,
      LogLevel.error => RecordTone.error,
      LogLevel.info => RecordTone.neutral,
      LogLevel.debug || LogLevel.silent => RecordTone.muted,
    };
    final payload = LogPayload.parse(log.payload);
    final accentColor = tone.accentColor(context);
    final cardBgColor = tone.tintColor(context) ??
        context.colorScheme.surfaceContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: cardBgColor,
          shape: SuperellipseBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            side: commonCardBorderSide(context),
          ),
        ),
        child: InkWell(
          customBorder: const SuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          onTap: () {
            globalState.showCommonDialog(child: LogDetailDialog(log: log));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RecordHeader(
                  children: [
                    RecordTimestamp(log.dateTime),
                    RecordLabel(
                      label: log.logLevel.name,
                      tone: tone,
                      onPressed: () => onClick?.call(log.logLevel.name),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _LogBody(
                  payload: payload,
                  errorColor: accentColor ?? context.colorScheme.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LogDetailDialog extends StatelessWidget {
  final Log log;

  const LogDetailDialog({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final payload = LogPayload.parse(log.payload);
    return CommonDialog(
      title: appLocalizations.details,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          _LogBody(
            payload: payload,
            errorColor: context.colorScheme.error,
          ),
          const Divider(),
          SelectableText(
            log.payload,
            style: context.textTheme.bodySmall?.toJetBrainsMono.copyWith(
              color: log.logLevel.color,
            ),
          ),
          SelectableText(
            log.dateTime,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
