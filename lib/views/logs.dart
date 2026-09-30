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
  var _autoScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ReverseScrollController();
    WidgetsBinding.instance.addObserver(this);
    _startLog();
  }

  // The in-memory list is dropped so the entry transition stays on the
  // illustration; the core-side window is restored once the route has settled,
  // which is also when live streaming starts (the core keeps recording while
  // this page is closed, so nothing from the transition is lost).
  void _startLog() {
    ref.read(logsProvider.notifier).clearLogs();
    ref.read(logsSearchProvider.notifier).state = '';
    ref.read(logsKeywordsProvider.notifier).state = [];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await waitRouteSettled(context);
      if (!mounted) return;
      clashCore.startLog();
      await _restoreLogs();
    });
  }

  Future<void> _restoreLogs() async {
    final history = await clashCore.getLogs();
    if (!mounted || history.isEmpty) return;
    final received = ref.read(logsProvider).list;
    final receivedKeys = received
        .map((item) => '${item.dateTime}\u0000${item.payload}')
        .toSet();
    ref.read(logsProvider.notifier).setLogs([
      ...history.where(
        (item) => !receivedKeys.contains('${item.dateTime}\u0000${item.payload}'),
      ),
      ...received,
    ]);
    _jumpToEnd();
  }

  // The entry snapshot must land on the tail (newest at the visual top).
  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final positions = _scrollController.positions;
      if (positions.isEmpty) return;
      final position = positions.last;
      if (position.pixels != position.maxScrollExtent) {
        position.jumpTo(position.maxScrollExtent);
      }
    });
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

  void _toggleAutoScroll() {
    setState(() {
      _autoScrollToEnd = !_autoScrollToEnd;
    });
  }

  void _cancelAutoScroll() {
    if (_autoScrollToEnd) {
      setState(() {
        _autoScrollToEnd = false;
      });
    }
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
    final hasLogs = logs.isNotEmpty;
    return CommonScaffold(
      actions: [
        IconButton(
          onPressed: _handleLogLevelSettings,
          icon: const Icon(FluentIcons.settings_24_regular),
          tooltip: appLocalizations.logLevel,
        ),
        IconButton(
          style: _autoScrollToEnd
              ? ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    context.colorScheme.secondaryContainer,
                  ),
                )
              : null,
          onPressed: _toggleAutoScroll,
          tooltip: appLocalizations.autoScroll,
          icon: const Icon(FluentIcons.swipe_up_24_regular),
        ),
        Tooltip(
          message: appLocalizations.export,
          child: InkWell(
            onTap: _handleExport,
            onLongPress: _handleClearLogs,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(FluentIcons.save_edit_24_regular, size: 24),
            ),
          ),
        ),
      ],
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      body: NullStatusSwitcher(
        isEmpty: !hasLogs,
        nullStatus: NullStatus(
          label: appLocalizations.nullTip(appLocalizations.logs),
          illustration: NullStatusIllustration.logs,
        ),
        child: ScrollToEndBox(
          onCancelToEnd: _cancelAutoScroll,
          controller: _scrollController,
          enable: _autoScrollToEnd,
          reverse: true,
          dataSource: logs,
          child: CommonScrollBar(
            controller: _scrollController,
            child: Align(
              alignment: Alignment.topCenter,
              child: ListView.builder(
                physics: const NextClampingScrollPhysics(),
                reverse: true,
                shrinkWrap: logs.length < 20,
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return LogItem(
                    key: ValueKey(log.dateTime),
                    index: index,
                    count: logs.length,
                    reversed: true,
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
        ),
      ),
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;
  final int index;
  final int count;
  final bool reversed;

  const LogItem({
    super.key,
    required this.log,
    this.onClick,
    required this.index,
    required this.count,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ContinuousListItem(
        index: index,
        count: count,
        reversed: reversed,
        standalone: true,
        child: ListItem(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () {
            globalState.showCommonDialog(child: LogDetailDialog(log: log));
          },
          title: EmojiText(
            log.payload,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyLarge?.copyWith(
              color: log.logLevel.color,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CommonChip(
                  onPressed: () {
                    onClick?.call(log.logLevel.name);
                  },
                  label: log.logLevel.name,
                ),
                Text(
                  log.dateTime,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.opacity80,
                  ),
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
        spacing: 6,
        children: [
          SelectableText(
            log.payload,
            style: context.textTheme.bodyLarge?.copyWith(
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
