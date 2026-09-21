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

class _FilledResizeImageIcon extends StatelessWidget {
  const _FilledResizeImageIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).iconTheme.color ??
        context.colorScheme.onSurface;
    return SvgPicture.string(
      '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M2.75 11C2.33579 11 2 10.6642 2 10.25V5.25C2 3.45507 3.45507 2 5.25 2H18.75C20.5449 2 22 3.45507 22 5.25V18.75C22 20.5449 20.5449 22 18.75 22H13.75C13.3358 22 13 21.6642 13 21.25C13 20.8358 13.3358 20.5 13.75 20.5H18.75C19.7165 20.5 20.5 19.7165 20.5 18.75V5.25C20.5 4.2835 19.7165 3.5 18.75 3.5H5.25C4.2835 3.5 3.5 4.2835 3.5 5.25V10.25C3.5 10.6642 3.16421 11 2.75 11ZM4 12C2.34315 12 1 13.3431 1 15V20C1 20.5564 1.15145 21.0773 1.41536 21.524L4.90901 18.0303C5.78769 17.1516 7.21231 17.1517 8.09099 18.0303L11.5846 21.524C11.8486 21.0773 12 20.5564 12 20V15C12 13.3431 10.6569 12 9 12H4ZM4 23C3.44364 23 2.92266 22.8486 2.47602 22.5846L5.96967 19.091C6.26256 18.7981 6.73744 18.7981 7.03033 19.091L10.524 22.5846C10.0773 22.8486 9.55636 23 9 23H4ZM9 16C8.44772 16 8 15.5523 8 15C8 14.4477 8.44772 14 9 14C9.55229 14 10 14.4477 10 15C10 15.5523 9.55229 16 9 16Z" fill="black"/>'
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
          icon: const _FilledResizeImageIcon(),
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
