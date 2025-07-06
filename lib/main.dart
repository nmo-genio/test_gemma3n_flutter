// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/core/services/logger_service.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/services/error_handler_service.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/ai_status/presentation/pages/gemma_status_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  LoggerService.init();
  final logger = LoggerService.instance;
  logger.i('🚀 Starting Educational AI Assistant with Gemma 3n');

  // Initialize storage services
  await StorageService.init();
  logger.i('📦 Storage services initialized');

  // Initialize error handling
  ErrorHandlerService.init();
  logger.i('🛡️ Error handling initialized');

  // Request permissions early
  await _requestPermissions();
  logger.i('✅ Permissions requested');

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      observers: [
        _ProviderLogger(),
      ],
      child: const MyApp(),
    ),
  );
}

/// Request necessary permissions for the app
Future<void> _requestPermissions() async {
  final logger = FeatureLogger('Permissions');

  try {
    // Storage permission
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      final result = await Permission.storage.request();
      logger.i('Storage permission: $result');
    }

    // Microphone permission (for Hour 2)
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      logger.i('Microphone permission will be requested when needed');
    }

  } catch (e) {
    logger.e('Error requesting permissions', error: e);
  }
}

/// Provider observer for debugging state changes
class _ProviderLogger extends ProviderObserver {
  final logger = FeatureLogger('Riverpod');

  @override
  void didUpdateProvider(
      ProviderBase provider,
      Object? previousValue,
      Object? newValue,
      ProviderContainer container,
      ) {
    if (provider.name != null) {
      logger.d('Provider Updated: ${provider.name}');
    }
  }

  @override
  void providerDidFail(
      ProviderBase provider,
      Object error,
      StackTrace stackTrace,
      ProviderContainer container,
      ) {
    logger.e(
        'Provider Failed: ${provider.name ?? provider.runtimeType}',
        error: error,
        stackTrace: stackTrace
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Educational AI Assistant - Gemma 3n',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const GemmaStatusPage(), // Your enhanced page
    );
  }
}