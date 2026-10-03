import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:path/path.dart' as p;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';

enum ClockCardType {
  medium,
  large;

  String get imagePrefKey => 'clock_card_${name}_image';
  String get textPrefKey => 'clock_card_${name}_text';
}

class ClockCardData {
  final String? imagePath;
  final String? customText;

  const ClockCardData({this.imagePath, this.customText});

  ClockCardData copyWith({
    String? imagePath,
    String? customText,
    bool clearImage = false,
    bool clearText = false,
  }) {
    return ClockCardData(
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      customText: clearText ? null : (customText ?? this.customText),
    );
  }
}

final clockCardMediumProvider =
    StateNotifierProvider<ClockCardNotifier, ClockCardData>((ref) {
      return ClockCardNotifier(ClockCardType.medium);
    });

final clockCardLargeProvider =
    StateNotifierProvider<ClockCardNotifier, ClockCardData>((ref) {
      return ClockCardNotifier(ClockCardType.large);
    });

class ClockCardNotifier extends StateNotifier<ClockCardData> {
  final ClockCardType cardType;

  ClockCardNotifier(this.cardType) : super(const ClockCardData()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final imagePath = prefs?.getString(cardType.imagePrefKey);
    final customText = prefs?.getString(cardType.textPrefKey);
    state = ClockCardData(imagePath: imagePath, customText: customText);
  }

  Future<void> updateText(String? text) async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs?.remove(cardType.textPrefKey);
      state = state.copyWith(clearText: true);
    } else {
      await prefs?.setString(cardType.textPrefKey, trimmed);
      state = state.copyWith(customText: trimmed);
    }
  }

  Future<void> updateImage(String? path) async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (path == null) {
      if (state.imagePath != null) {
        try {
          final file = File(state.imagePath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
      await prefs?.remove(cardType.imagePrefKey);
      state = state.copyWith(clearImage: true);
    } else {
      await prefs?.setString(cardType.imagePrefKey, path);
      state = state.copyWith(imagePath: path);
    }
  }
}

Future<String?> _saveSelectedImage(String sourcePath, ClockCardType type) async {
  try {
    final baseDir = await appPath.dataDir.future;
    final dir = Directory(p.join(baseDir.path, 'clock_card_images'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final ext =
        p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = '${type.name}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(dir.path, fileName);
    await File(sourcePath).copy(targetPath);
    return targetPath;
  } catch (e) {
    commonPrint.log('Failed to save clock card image: $e');
    return sourcePath;
  }
}

class ClockCard extends ConsumerWidget {
  final ClockCardType type;

  const ClockCard({super.key, required this.type});

  Future<void> _showEditTextDialog(
    BuildContext context,
    WidgetRef ref,
    ClockCardData data,
  ) async {
    final notifier = type == ClockCardType.medium
        ? ref.read(clockCardMediumProvider.notifier)
        : ref.read(clockCardLargeProvider.notifier);

    final newText = await globalState.showCommonDialog<String>(
      child: _ClockCardTextDialog(initialValue: data.customText ?? ''),
    );
    if (newText != null) {
      await notifier.updateText(newText);
    }
  }

enum _ImageAction { change, restore }

  Future<void> _showImageActionMenu(
    BuildContext context,
    WidgetRef ref,
    ClockCardData data,
  ) async {
    final notifier = type == ClockCardType.medium
        ? ref.read(clockCardMediumProvider.notifier)
        : ref.read(clockCardLargeProvider.notifier);

    final action = await globalState.showCommonDialog<_ImageAction>(
      child: Builder(
        builder: (dialogContext) => CommonDialog(
          title: type == ClockCardType.medium
              ? appLocalizations.clockMedium
              : appLocalizations.clockLarge,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(appLocalizations.cancel),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(FluentIcons.image_24_regular),
                title: Text(appLocalizations.changeImage),
                onTap: () =>
                    Navigator.of(dialogContext).pop(_ImageAction.change),
              ),
              if (data.imagePath != null)
                ListTile(
                  leading: const Icon(FluentIcons.arrow_reset_24_regular),
                  title: Text(appLocalizations.restoreDefaultImage),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(_ImageAction.restore),
                ),
            ],
          ),
        ),
      ),
    );

    if (action == _ImageAction.change) {
      try {
        final rawPath = await picker.pickImage();
        if (rawPath != null && rawPath.isNotEmpty) {
          final savedPath = await _saveSelectedImage(rawPath, type);
          await notifier.updateImage(savedPath);
        }
      } catch (e) {
        commonPrint.log('Pick image error: $e');
      }
    } else if (action == _ImageAction.restore) {
      await notifier.updateImage(null);
    }
  }

  Widget _buildDefaultBackground(bool isDark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF1E293B)]
              : const [Color(0xFFE0E7FF), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = type == ClockCardType.medium
        ? ref.watch(clockCardMediumProvider)
        : ref.watch(clockCardLargeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasCustomImage =
        data.imagePath != null && File(data.imagePath!).existsSync();

    return RepaintBoundary(
      child: CommonCard(
        onPressed: () => _showEditTextDialog(context, ref, data),
        onLongPress: () => _showImageActionMenu(context, ref, data),
        padding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTap: () => _showImageActionMenu(context, ref, data),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCustomImage)
                Image.file(
                  File(data.imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => _buildDefaultBackground(isDark),
                )
              else
                _buildDefaultBackground(isDark),

              Container(
                color: isDark
                    ? Colors.black.withOpacity(0.35)
                    : Colors.white.withOpacity(0.18),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.black.withOpacity(0.40), Colors.transparent]
                          : [Colors.white.withOpacity(0.40), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                  child: ValueListenableBuilder<int>(
                    valueListenable: dashboardRefreshManager.tick1s,
                    builder: (_, _, _) {
                      final now = DateTime.now();
                      final hour = now.hour.toString().padLeft(2, '0');
                      final minute = now.minute.toString().padLeft(2, '0');
                      final timeText = '$hour:$minute';

                      final titleColor =
                          isDark ? Colors.white : const Color(0xFF0F172A);
                      final shadow = isDark
                          ? const Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            )
                          : Shadow(
                              color: Colors.white.withOpacity(0.9),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            );

                      return Row(
                        children: [
                          Icon(
                            FluentIcons.clock_20_regular,
                            size: 18,
                            color: titleColor,
                            shadows: [shadow],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              shadows: [shadow],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? Colors.black.withOpacity(0.50)
                            : Colors.white.withOpacity(0.68),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white.withOpacity(0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        data.customText ??
                            appLocalizations.clockWidgetDefaultText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? (data.customText != null
                                  ? Colors.white
                                  : Colors.white70)
                              : (data.customText != null
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF475569)),
                          shadows: isDark
                              ? const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : const [
                                  Shadow(
                                    color: Colors.white60,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClockCardMedium extends StatelessWidget {
  const ClockCardMedium({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(2),
      child: const ClockCard(type: ClockCardType.medium),
    );
  }
}

class ClockCardLarge extends StatelessWidget {
  const ClockCardLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(2),
      child: const ClockCard(type: ClockCardType.large),
    );
  }
}

class _ClockCardTextDialog extends StatefulWidget {
  final String initialValue;

  const _ClockCardTextDialog({required this.initialValue});

  @override
  State<_ClockCardTextDialog> createState() => _ClockCardTextDialogState();
}

class _ClockCardTextDialogState extends State<_ClockCardTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EmojiTextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.customCardText,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text);
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: TextField(
          controller: _controller,
          maxLength: 80,
          decoration: InputDecoration(
            hintText: appLocalizations.customCardTextHint,
          ),
        ),
      ),
    );
  }
}
