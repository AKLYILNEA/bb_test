import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:bett_box/common/common.dart';
import 'package:path/path.dart';

class UiManager {
  static UiManager? _instance;

  UiManager._internal();

  factory UiManager() {
    _instance ??= UiManager._internal();
    return _instance!;
  }

  /// 初始化 UI 文件
  Future<void> initializeUI() async {
    try {
      final uiPath = await appPath.uiPath;
      final uiDir = Directory(uiPath);

      // Check version file
      final versionFile = File(join(uiPath, '.ui_version'));
      const currentVersion = '2.6.1'; // Update version

      if (await uiDir.exists()) {
        final files = await uiDir.list().toList();
        if (files.isNotEmpty) {
          // Check version
          if (await versionFile.exists()) {
            final existingVersion = await versionFile.readAsString();
            if (existingVersion.trim() == currentVersion) {
              commonPrint.log('UI already up to date (v$currentVersion)');
              return;
            }
            commonPrint.log('UI version mismatch: $existingVersion -> $currentVersion');
          }
          // Clear old UI for update
          await clearUI();
        }
      }

      commonPrint.log('Extracting UI from assets...');

      // 创建 UI 目录
      await uiDir.create(recursive: true);

      // 从 assets 读取 zip 文件
      final zipData = await rootBundle.load('assets/data/zash.zip');
      final bytes = zipData.buffer.asUint8List();

      // 解压到临时目录
      final tempPath = await appPath.tempPath;
      final tempExtractPath = join(
        tempPath,
        'ui_extract_${DateTime.now().millisecondsSinceEpoch}',
      );
      final tempExtractDir = Directory(tempExtractPath);
      await tempExtractDir.create(recursive: true);

      try {
        // 解压 zip 文件
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;
          final filePath = join(tempExtractPath, filename);

          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
        }

        // 移动文件到目标目录
        final extractedFiles = await tempExtractDir.list().toList();
        String sourceDir = tempExtractPath;

        if (extractedFiles.length == 1 && extractedFiles.first is Directory) {
          sourceDir = extractedFiles.first.path;
        }

        await _copyDirectory(Directory(sourceDir), uiDir);

        final versionFile = File(join(uiPath, '.ui_version'));
        await versionFile.writeAsString(currentVersion);

        commonPrint.log('UI extracted successfully to: $uiPath (v$currentVersion)');
      } finally {
        if (await tempExtractDir.exists()) {
          await tempExtractDir.delete(recursive: true);
        }
      }
    } catch (e) {
      commonPrint.log('Error extracting UI: $e');
      rethrow;
    }
  }

  /// 递归复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(
          join(destination.path, basename(entity.path)),
        );
        await newDirectory.create(recursive: true);
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(join(destination.path, basename(entity.path)));
        await entity.copy(newFile.path);
      }
    }
  }

  /// 清理 UI 文件
  Future<void> clearUI() async {
    try {
      final uiPath = await appPath.uiPath;
      final uiDir = Directory(uiPath);

      if (await uiDir.exists()) {
        await uiDir.delete(recursive: true);
        commonPrint.log('UI cleared successfully');
      }
    } catch (e) {
      commonPrint.log('Error clearing UI: $e');
    }
  }
}

final uiManager = UiManager();
