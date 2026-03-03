import 'dart:async';
import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/widgets/fade_box.dart';
import 'package:flutter/material.dart';

class MessageManager extends StatefulWidget {
  final Widget child;

  const MessageManager({super.key, required this.child});

  @override
  State<MessageManager> createState() => MessageManagerState();
}

class MessageManagerState extends State<MessageManager> {
  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final List<CommonMessage> _bufferMessages = [];
  bool _pushing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messagesNotifier.dispose();
    super.dispose();
  }

  Future<void> message(
    String text, {
    VoidCallback? onAction,
    String? actionLabel,
  }) async {
    if (_messagesNotifier.value.any((m) => m.text == text) ||
        _bufferMessages.any((m) => m.text == text)) {
      return;
    }

    final commonMessage = CommonMessage(
      id: utils.uuidV4,
      text: text,
      onAction: onAction,
      actionLabel: actionLabel,
    );
    _bufferMessages.add(commonMessage);
    await _showMessage();
  }

  Future<void> _showMessage() async {
    if (_pushing == true) {
      return;
    }
    _pushing = true;
    while (_bufferMessages.isNotEmpty) {
      final commonMessage = _bufferMessages.removeAt(0);
      _messagesNotifier.value = List.from(_messagesNotifier.value)
        ..add(commonMessage);
      await Future.delayed(Duration(seconds: 1));
      Future.delayed(commonMessage.duration, () {
        _handleRemove(commonMessage);
      });
      if (_bufferMessages.isEmpty) {
        _pushing = false;
      }
    }
  }

  void _handleRemove(CommonMessage commonMessage) {
    _messagesNotifier.value = List<CommonMessage>.from(_messagesNotifier.value)
      ..remove(commonMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder(
          valueListenable: _messagesNotifier,
          builder: (_, messages, _) {
            return FadeThroughBox(
              margin: EdgeInsets.only(
                top: kToolbarHeight + 8,
                left: 12,
                right: 12,
              ),
              alignment: Alignment.topRight,
              child: messages.isEmpty
                  ? SizedBox()
                  : LayoutBuilder(
                      key: Key(messages.last.id),
                      builder: (_, constraints) {
                        return Card(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12.0),
                            ),
                          ),
                          elevation: 10,
                          color: context.colorScheme.surfaceContainerHigh,
                          child: Container(
                            width: min(constraints.maxWidth, 500),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(child: Text(messages.last.text)),
                                if (messages.last.actionLabel != null &&
                                    messages.last.onAction != null) ...[
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      final message = messages.last;
                                      _handleRemove(message);
                                      message.onAction?.call();
                                    },
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      foregroundColor:
                                          context.colorScheme.primary,
                                    ),
                                    child: Text(messages.last.actionLabel!),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }
}
