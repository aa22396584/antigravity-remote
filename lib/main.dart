import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/storage_service.dart';
import 'features/device/providers/device_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StorageService? storageService;
  try {
    storageService = await StorageService.init();
  } catch (_) {
    // If storage initialization fails, gracefully proceed in memory
  }

  runApp(
    ProviderScope(
      overrides: [
        if (storageService != null)
          storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const AntigravityRemoteApp(),
    ),
  );
}
