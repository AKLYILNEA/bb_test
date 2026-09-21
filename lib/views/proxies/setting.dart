import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class _MinStorageIcon extends StatelessWidget {
  const _MinStorageIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).iconTheme.color ??
        context.colorScheme.onSurface;
    return SvgPicture.string(
      '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M5 7H19C20.5977 7 21.9037 8.24892 21.9949 9.82373L22 10V14C22 15.5977 20.7511 16.9037 19.1763 16.9949L19 17H5C3.40232 17 2.09634 15.7511 2.00509 14.1763L2 14V10C2 8.40232 3.24892 7.09634 4.82373 7.00509L5 7H19H5ZM19 8.5H5C4.17157 8.5 3.5 9.1716 3.5 10V14C3.5 14.8284 4.17157 15.5 5 15.5H19C19.8284 15.5 20.5 14.8284 20.5 14V10C20.5 9.1716 19.8284 8.5 19 8.5Z" fill="black"/>'
      '</svg>',
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
class _PictureInPictureIcon extends StatelessWidget {
  const _PictureInPictureIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).iconTheme.color ??
        context.colorScheme.onSurface;
    return SvgPicture.string(
      '<svg width="24" height="24" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M16 12.75a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z" fill="black"/>'
      '<path d="M8 10.5A1.5 1.5 0 0 1 9.5 9h8a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1-1.5 1.5h-8A1.5 1.5 0 0 1 8 15.5v-5Zm1.5 0v4.394l2.082-2.255a1.25 1.25 0 0 1 1.836 0l2.633 2.852-.01.009H17.5v-5h-8Zm3 3.356L10.982 15.5h3.036L12.5 13.856Z" fill="black"/>'
      '<path d="M5.75 4A3.75 3.75 0 0 0 2 7.75v8.5A3.75 3.75 0 0 0 5.75 20h12.5A3.75 3.75 0 0 0 22 16.25v-8.5A3.75 3.75 0 0 0 18.25 4H5.75ZM3.5 7.75A2.25 2.25 0 0 1 5.75 5.5h12.5a2.25 2.25 0 0 1 2.25 2.25v8.5a2.25 2.25 0 0 1-2.25 2.25H5.75a2.25 2.25 0 0 1-2.25-2.25v-8.5Z" fill="black"/>'
      '</svg>',
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class ProxiesSetting extends StatelessWidget {
  const ProxiesSetting({super.key});

  IconData _getIconWithProxiesType(ProxiesType type) {
    return switch (type) {
      ProxiesType.tab => FluentIcons.app_recent_24_regular,
      ProxiesType.list => FluentIcons.apps_list_detail_24_regular,
    };
  }

  IconData _getIconWithProxiesSortType(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => FluentIcons.text_align_left_24_regular,
      ProxiesSortType.delay => FluentIcons.top_speed_24_regular,
      ProxiesSortType.name => FluentIcons.text_sort_ascending_24_regular,
    };
  }

  String _getStringProxiesSortType(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => appLocalizations.defaultText,
      ProxiesSortType.delay => appLocalizations.delay,
      ProxiesSortType.name => appLocalizations.name,
    };
  }

  String getTextForProxiesLayout(ProxiesLayout proxiesLayout) {
    return switch (proxiesLayout) {
      ProxiesLayout.tight => appLocalizations.tight,
      ProxiesLayout.standard => appLocalizations.standard,
      ProxiesLayout.loose => appLocalizations.loose,
    };
  }

  String _getTextWithProxiesIconStyle(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => appLocalizations.standard,
      ProxiesIconStyle.none => appLocalizations.noIcon,
      ProxiesIconStyle.icon => appLocalizations.onlyIcon,
    };
  }

  List<Widget> _buildStyleSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.style,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final proxiesType = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.type),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesType.values)
                    SettingInfoCard(
                      Info(
                        label: Intl.message(item.name),
                        iconData: _getIconWithProxiesType(item),
                      ),
                      isSelected: proxiesType == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(
                                type: item,
                                hasCustomizedStyle: true,
                              );
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSortSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.sort,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final sortType = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.sortType),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesSortType.values)
                    SettingInfoCard(
                      Info(
                        label: _getStringProxiesSortType(item),
                        iconData: _getIconWithProxiesSortType(item),
                      ),
                      isSelected: sortType == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(sortType: item);
                            });
                        ref.read(sortNumProvider.notifier).add();
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Info _getInfoWithProxiesLayout(ProxiesLayout proxiesLayout) {
    return switch (proxiesLayout) {
      ProxiesLayout.tight => Info(
          label: getTextForProxiesLayout(proxiesLayout),
          iconData: FluentIcons.dock_row_24_regular,
        ),
      ProxiesLayout.standard => Info(
          label: getTextForProxiesLayout(proxiesLayout),
          iconData: FluentIcons.grid_24_regular,
        ),
      ProxiesLayout.loose => Info(
          label: getTextForProxiesLayout(proxiesLayout),
          icon: const RotatedBox(
            quarterTurns: 1,
            child: Icon(FluentIcons.pause_24_regular),
          ),
        ),
    };
  }

  Info _getInfoWithProxyCardType(ProxyCardType cardType) {
    return switch (cardType) {
      ProxyCardType.expand => Info(
          label: Intl.message(cardType.name),
          iconData: FluentIcons.maximize_24_regular,
        ),
      ProxyCardType.shrink => Info(
          label: Intl.message(cardType.name),
          iconData: FluentIcons.system_24_regular,
        ),
      ProxyCardType.min => Info(
          label: Intl.message(cardType.name),
          icon: const _MinStorageIcon(),
        ),
    };
  }

  Info _getInfoWithProxiesIconStyle(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => Info(
          label: _getTextWithProxiesIconStyle(style),
          icon: const _PictureInPictureIcon(),
        ),
      ProxiesIconStyle.none => Info(
          label: _getTextWithProxiesIconStyle(style),
          iconData: FluentIcons.image_off_24_regular,
        ),
      ProxiesIconStyle.icon => Info(
          label: _getTextWithProxiesIconStyle(style),
          iconData: FluentIcons.image_24_regular,
        ),
    };
  }

  List<Widget> _buildSizeSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.size,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final cardType = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.cardType),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxyCardType.values)
                    SettingInfoCard(
                      _getInfoWithProxyCardType(item),
                      isSelected: item == cardType,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(cardType: item);
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLayoutSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.layout,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final layout = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.layout),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesLayout.values)
                    SettingInfoCard(
                      _getInfoWithProxiesLayout(item),
                      isSelected: item == layout,
                      onPressed: () {
                        ref
                            .watch(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(layout: item);
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupStyleSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.iconStyle,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final iconStyle = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.iconStyle),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesIconStyle.values)
                    SettingInfoCard(
                      _getInfoWithProxiesIconStyle(item),
                      isSelected: iconStyle == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(
                                iconStyle: item,
                                hasCustomizedStyle: true,
                              );
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildStyleSetting(),
          ..._buildSortSetting(),
          ..._buildLayoutSetting(),
          ..._buildSizeSetting(),
          Consumer(
            builder: (_, ref, child) {
              final isList = ref.watch(
                proxiesStyleSettingProvider.select(
                  (state) => state.type == ProxiesType.list,
                ),
              );
              if (isList) {
                return child!;
              }
              return Container();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [..._buildGroupStyleSetting()],
            ),
          ),
        ],
      ),
    );
  }
}
