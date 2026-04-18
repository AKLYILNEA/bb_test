import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua =>
      ['Clash.Meta/Mihomo/ClashMetaForAndroid/v5.0'].join(' ');
}
