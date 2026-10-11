import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/pages/pages.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class MediaUnlockSmall extends ConsumerStatefulWidget {
  const MediaUnlockSmall({super.key});

  @override
  ConsumerState<MediaUnlockSmall> createState() => _MediaUnlockSmallState();
}

class _MediaUnlockSmallState extends ConsumerState<MediaUnlockSmall> {
  MediaUnlockState? _lastState;
  List<MediaPlatform>? _lastDisplayedPlatforms;
  bool? _lastColorfulIcons;
  Widget? _cachedCard;

  bool _shouldRebuildCard({
    required MediaUnlockState newState,
    required List<MediaPlatform> displayedPlatforms,
    required bool colorfulIcons,
  }) {
    if (_lastState == null ||
        _cachedCard == null ||
        _lastDisplayedPlatforms == null ||
        _lastColorfulIcons == null) {
      return true;
    }
    if (!listEquals(_lastDisplayedPlatforms, displayedPlatforms)) {
      return true;
    }
    if (_lastColorfulIcons != colorfulIcons) {
      return true;
    }
    if (_lastState!.isLoading != newState.isLoading) {
      return true;
    }
    for (final p in displayedPlatforms) {
      if (_lastState!.testingPlatforms.contains(p) !=
          newState.testingPlatforms.contains(p)) {
        return true;
      }
      if (_lastState!.results[p] != newState.results[p]) {
        return true;
      }
    }
    return false;
  }

  Widget _buildPlatformRow(
    MediaPlatform platform,
    MediaUnlockResult? result,
    bool isLoading,
    BuildContext context, {
    bool isItemTesting = false,
    required bool colorfulIcons,
    required int count,
  }) {
    final isTesting = isItemTesting ||
        (isLoading &&
            (result == null || result.status == MediaUnlockStatus.testing));
    final status = isTesting
        ? MediaUnlockStatus.testing
        : (result?.status ??
            (isLoading ? MediaUnlockStatus.testing : MediaUnlockStatus.unknown));
    final color = status.statusColor(context.colorScheme);

    final double iconBoxSize;
    final double textFontSize;
    final double dotSize;
    final double horizontalPadding;
    final double iconSpacing;

    if (count == 1) {
      iconBoxSize = 28.ap;
      textFontSize = 15.ap;
      dotSize = 9.ap;
      horizontalPadding = 16.ap;
      iconSpacing = 12.ap;
    } else if (count == 2) {
      iconBoxSize = 22.ap;
      textFontSize = 13.5.ap;
      dotSize = 8.5.ap;
      horizontalPadding = 14.ap;
      iconSpacing = 10.ap;
    } else if (count == 3) {
      iconBoxSize = 19.ap;
      textFontSize = 13.ap;
      dotSize = 8.ap;
      horizontalPadding = 12.ap;
      iconSpacing = 8.ap;
    } else {
      iconBoxSize = 17.ap;
      textFontSize = 12.ap;
      dotSize = 7.5.ap;
      horizontalPadding = 12.ap;
      iconSpacing = 8.ap;
    }

    final double iconSize = iconBoxSize - 2.ap;
    final Widget icon;
    if (platform.isMonochrome) {
      icon = SvgPicture.asset(
        'assets/images/platforms/${platform.name}.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          context.colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
    } else if (colorfulIcons) {
      icon = SvgPicture.asset(
        'assets/images/platforms/${platform.name}.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    } else {
      icon = ColorFiltered(
        colorFilter: monochromeColorFilter,
        child: SvgPicture.asset(
          'assets/images/platforms/${platform.name}.svg',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capsuleBg = context.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.45 : 0.55,
    );

    return DecoratedBox(
      key: ValueKey(platform),
      decoration: ShapeDecoration(
        color: capsuleBg,
        shape: const SuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(1000)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: iconBoxSize,
              height: iconBoxSize,
              child: Center(
                child: themedPlatformIcon(context, platform, icon),
              ),
            ),
            SizedBox(width: iconSpacing),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform.defaultName,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: textFontSize,
                      color: context.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (count == 1 && result?.latency != null) ...[
                    SizedBox(height: 2.ap),
                    Text(
                      '${result!.latency}ms',
                      style: context.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5.ap,
                        fontWeight: FontWeight.w500,
                        color: context.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.ap),
            SizedBox(
              width: dotSize + 4.ap,
              height: dotSize + 4.ap,
              child: Center(
                child: isTesting
                    ? RepaintBoundary(
                        child: SizedBox(
                          width: dotSize + 3.ap,
                          height: dotSize + 3.ap,
                          child: SpinKitFadingCircle(
                            color: context.colorScheme.primary,
                            size: dotSize + 3.ap,
                          ),
                        ),
                      )
                    : Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: ShapeDecoration(
                          color: color,
                          shape: const CircleBorder(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = ref.watch(
      appSettingProvider.select((state) => state.pinnedMediaPlatforms),
    );
    final colorfulIcons = ref.watch(
      appSettingProvider.select((state) => state.mediaUnlockColorfulIcons),
    );
    final displayedPlatforms =
        (pinned.isNotEmpty ? pinned : defaultPinnedMediaPlatforms)
            .take(4)
            .toList();

    return SizedBox(
      height: getWidgetHeight(2),
      child: ValueListenableBuilder<MediaUnlockState>(
        valueListenable: mediaUnlockState.state,
        builder: (context, state, _) {
          final shouldRebuild = _shouldRebuildCard(
            newState: state,
            displayedPlatforms: displayedPlatforms,
            colorfulIcons: colorfulIcons,
          );
          if (!shouldRebuild) {
            return _cachedCard!;
          }
          _lastState = state;
          _lastDisplayedPlatforms = displayedPlatforms;
          _lastColorfulIcons = colorfulIcons;

          final isWidgetLoading =
              displayedPlatforms.any(state.testingPlatforms.contains);

          final int count = displayedPlatforms.length;
          final double gap = count == 4
              ? 6.ap
              : (count == 3 ? 8.ap : (count == 2 ? 12.ap : 0.0));

          final card = CommonCard(
            onPressed: () {
              showExtend(
                context,
                builder: (_, type) => MediaUnlockPage(type: type),
              );
            },
            child: Column(
              children: [
                InfoHeader(
                  padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                  actionsHeight: globalState.measure.titleSmallHeight,
                  info: Info(
                    label: appLocalizations.mediaUnlockShort,
                    iconData: FluentIcons.link_24_regular,
                  ),
                  actions: [
                    SizedBox(
                      width: 24.ap,
                      height: 24.ap,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: isWidgetLoading
                            ? null
                            : () => mediaUnlockState.checkPlatforms(
                                  displayedPlatforms,
                                  force: true,
                                ),
                        icon: isWidgetLoading
                            ? RepaintBoundary(
                                child: SizedBox(
                                  width: 16.ap,
                                  height: 16.ap,
                                  child: SpinKitFadingCircle(
                                    color: context.colorScheme.primary,
                                    size: 16.ap,
                                  ),
                                ),
                              )
                            : Icon(
                                FluentIcons.arrow_sync_24_regular,
                                size: 18.ap,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.ap, 12.ap, 16.ap, 16.ap),
                    child: Column(
                      children: [
                        for (int i = 0; i < count; i++) ...[
                          if (i > 0) SizedBox(height: gap),
                          Expanded(
                            child: _buildPlatformRow(
                              displayedPlatforms[i],
                              state.results[displayedPlatforms[i]],
                              state.isLoading,
                              context,
                              isItemTesting: state.testingPlatforms
                                  .contains(displayedPlatforms[i]),
                              colorfulIcons: colorfulIcons,
                              count: count,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          _cachedCard = card;
          return card;
        },
      ),
    );
  }
}
