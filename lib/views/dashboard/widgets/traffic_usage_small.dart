import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 小型流量统计小部件：左侧标题 + 底部「上传 / 下载」数据，右侧缩小的流量圆环。
///
/// 长按卡片可在弹窗里切换显示上传还是下载（默认下载），选择写进偏好、重启后保留。
class TrafficUsageSmall extends ConsumerStatefulWidget {
  const TrafficUsageSmall({super.key});

  @override
  ConsumerState<TrafficUsageSmall> createState() => _TrafficUsageSmallState();
}

class _TrafficUsageSmallState extends ConsumerState<TrafficUsageSmall> {
  /// 圆环边长：47（先是 60、后是 40、再是 45，按需求定稿 47），
  /// 上下与右侧留白 = (卡片高度 - 圆环边长) / 2 = 18.5，三者一致即上下居中。
  static const double _donutSize = 47;

  static double get _donutEdge => (getWidgetHeight(1) - _donutSize) / 2;

  bool _showUpload = false;

  @override
  void initState() {
    super.initState();
    preferences.getTrafficUsageShowUpload().then((value) {
      if (!mounted || value == _showUpload) {
        return;
      }
      setState(() {
        _showUpload = value;
      });
    });
  }

  void _showDisplaySettings() {
    globalState.showCommonDialog<void>(
      child: CommonDialog(
        title: appLocalizations.trafficUsage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(appLocalizations.upload),
              trailing: _showUpload ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _setShowUpload(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(appLocalizations.download),
              trailing: _showUpload ? null : const Icon(Icons.check_rounded),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _setShowUpload(false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setShowUpload(bool value) {
    if (_showUpload != value) {
      setState(() {
        _showUpload = value;
      });
    }
    preferences.setTrafficUsageShowUpload(value);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = globalState.theme.darken3PrimaryContainer;
    final secondaryColor = globalState.theme.darken2SecondaryContainer;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: _showDisplaySettings,
        child: ValueListenableBuilder<int>(
          valueListenable: dashboardRefreshManager.tick1s,
          builder: (_, _, _) {
            final totalTraffic = ref.read(totalTrafficProvider);
            final value = _showUpload ? totalTraffic.up : totalTraffic.down;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    // 左侧沿用卡片标准内边距，标题与其它卡片同一高度、底部同一基线
                    padding: EdgeInsets.only(
                      left: baseInfoEdgeInsets.left,
                      top: baseInfoEdgeInsets.top,
                      bottom: baseInfoEdgeInsets.bottom,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.data_usage_rounded,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              // 标题接近圆环时省略号收尾，避免与圆环贴到一起
                              child: TooltipText(
                                text: Text(
                                  appLocalizations.trafficUsage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 与其它数值卡同一套行盒与字号（bodyMedium + 1 → 15sp、行盒
                        // bodyMediumHeight + 2），底部与它们严格同一基线
                        SizedBox(
                          height: globalState.measure.bodyMediumHeight + 2,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: value.showValue),
                                      const TextSpan(text: ' '),
                                      TextSpan(
                                        text: value.showUnit,
                                        // 单位比数值小一号（再缩一档 → 约 10sp）；
                                        // 因为共享同一条基线，其底部（基线下沿）与左侧数值严格齐平
                                        style: context.textTheme.bodyMedium
                                            ?.toLighter
                                            .adjustSize(-4),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodyMedium?.toLight
                                      .adjustSize(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  // 上下与右侧留白一致（各 (卡片高度 - 圆环边长) / 2），圆环因此上下居中；
                  // 左侧只留一个贴边间距，把宽度让给标题，避免标题被压成省略号
                  padding: EdgeInsets.only(
                    left: 8,
                    top: _donutEdge,
                    right: _donutEdge,
                    bottom: _donutEdge,
                  ),
                  child: SizedBox(
                    width: _donutSize,
                    height: _donutSize,
                    child: DonutChart(
                      trackColor: context.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      data: [
                        DonutChartData(
                          value: totalTraffic.up.value.toDouble(),
                          color: primaryColor,
                        ),
                        DonutChartData(
                          value: totalTraffic.down.value.toDouble(),
                          color: secondaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
