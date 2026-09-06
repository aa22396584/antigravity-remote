import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/diagnostic_service.dart';
import 'core/services/storage_service.dart';
import 'features/device/providers/device_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Issue #32: 官方標準全局未捕捉錯誤收集至去識別化診斷日誌
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticService.instance.log(
      '[FlutterError] ${details.exceptionAsString()}',
      level: 'ERROR',
      category: 'framework',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticService.instance.log(
      '[PlatformError] $error',
      level: 'FATAL',
      category: 'platform',
    );
    return true;
  };

  StorageService storageService;
  try {
    storageService = await StorageService.init();
  } catch (_) {
    storageService = StorageService.inMemory(bootState: BootState.degraded);
  }

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const AntigravityRemoteApp(),
    ),
  );
}
