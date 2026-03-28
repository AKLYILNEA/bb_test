import 'dart:async';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  late final ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateConnections();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateConnections();
    });
  }

  Future<void> _updateConnections() async {
    final connections = await clashCore.getConnections();
    ref.read(connectionsProvider.notifier).state = connections;
  }

  Future<void> _handleBlockConnection(String id) async {
    clashCore.closeConnection(id);
    await _updateConnections();
  }

  void _handleCloseAll() async {
    clashCore.closeConnections();
    await _updateConnections();
  }

  void _onSearch(String value) {
    ref.read(connectionsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(connectionsKeywordsProvider.notifier).state = keywords;
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      actions: [
        IconButton(
          onPressed: _handleCloseAll,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
      body: Consumer(
        builder: (_, ref, _) {
          final connections = ref.watch(filteredConnectionsProvider);
          final hasConnections = connections.isNotEmpty;

          if (!hasConnections) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            itemBuilder: (context, index) {
              if (index.isOdd) {
                return const Divider(height: 0);
              }
              final itemIndex = index ~/ 2;
              if (itemIndex >= connections.length) {
                return const SizedBox.shrink();
              }
              final trackerInfo = connections[itemIndex];
              return TrackerInfoItem(
                key: ValueKey(trackerInfo.id),
                trackerInfo: trackerInfo,
                onClickKeyword: (value) {
                  context.commonScaffoldState?.addKeyword(value);
                },
                trailing: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size.zero),
                  ),
                  icon: const Icon(Icons.block),
                  onPressed: () => _handleBlockConnection(trackerInfo.id),
                ),
                detailTitle: appLocalizations.details(
                  appLocalizations.connection,
                ),
              );
            },
            itemExtentBuilder: (index, _) {
              if (index.isOdd) {
                return 0;
              }
              return TrackerInfoItem.height;
            },
            itemCount: connections.length * 2 - 1,
          );
        },
      ),
    );
  }
}
