import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/clash/interface.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/core.dart';
import 'package:bett_box/state.dart';

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;

  Process? process;

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _initServer();
    reStart();
  }

  Future<void> _initServer() async {
    runZonedGuarded(
      () async {
        final address = !system.isWindows
            ? InternetAddress(unixSocketPath, type: InternetAddressType.unix)
            : InternetAddress(localhost, type: InternetAddressType.IPv4);
        await _deleteSocketFile();
        final server = await ServerSocket.bind(address, 0, shared: true);
        serverCompleter.complete(server);
        await for (final socket in server) {
          await _destroySocket();
          socketCompleter.complete(socket);
          socket
              .transform(uint8ListToListIntConverter)
              .transform(utf8.decoder)
              .transform(LineSplitter())
              .listen((data) {
                handleResult(ActionResult.fromJson(json.decode(data.trim())));
              });
        }
      },
      (error, stack) {
        commonPrint.log(error.toString());
        if (error is SocketException) {
          globalState.showNotifier(error.toString());
          // globalState.appController.restartCore();
        }
      },
    );
  }

  @override
  reStart() async {
    if (isStarting) return;
    isStarting = true;
    socketCompleter = Completer();
    process?.kill();
    process = null;

    final serverSocket = await serverCompleter.future;
    final arg = system.isWindows ? '${serverSocket.port}' : serverSocket.address.address;

    if (system.isWindows) {
      // 强制使用 Helper 服务模式：先确保 Helper 服务已注册并启动
      final serviceOk = await windows?.registerService() ?? false;
      if (serviceOk) {
        final isSuccess = await request.startCoreByHelper(arg);
        if (isSuccess) {
          isStarting = false;
          return;
        }
      } else {
        // 注册服务失败（例如用户拒绝 UAC），提示但仍尝试直接启动核心（无服务模式，可能影响 TUN）
        globalState.showNotifier('服务启动失败，尝试直接启动核心');
      }
    }

    // 非 Windows 平台，或 Helper 启动失败时的回退方案：直接启动核心进程
    // 设置 SAFE_PATHS 环境变量，将应用数据目录添加到安全路径列表
    final homeDirPath = await appPath.homeDirPath;
    final environment = Map<String, String>.from(Platform.environment);
    environment['SAFE_PATHS'] = homeDirPath;

    process = await Process.start(appPath.corePath, [
      arg,
    ], environment: environment);
    process?.stdout.listen((_) {});
    process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error);
      }
    });
    isStarting = false;
  }

  @override
  destroy() async {
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  sendMessage(String message) async {
    final socket = await socketCompleter.future;
    socket.writeln(message);
  }

  Future<void> _deleteSocketFile() async {
    if (!system.isWindows) {
      final file = File(unixSocketPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      await lastSocket.close();
      socketCompleter = Completer();
    }
  }

  @override
  shutdown() async {
    if (system.isWindows) {
      await request.stopCoreByHelper();
    }
    await _destroySocket();
    process?.kill();
    process = null;
    return true;
  }

  @override
  Future<bool> preload() async {
    await serverCompleter.future;
    return true;
  }
}

final clashService = system.isDesktop ? ClashService() : null;
