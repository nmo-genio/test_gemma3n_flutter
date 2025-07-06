// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/core/services/logger_service.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/services/error_handler_service.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/routing/app_router.dart';

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
    // Microphone permission - always required for recording
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final micResult = await Permission.microphone.request();
      logger.i('Microphone permission: $micResult');
    }

    // Storage permissions - different approach for different Android versions
    await _requestStoragePermissions(logger);

  } catch (e) {
    logger.e('Error requesting permissions', error: e);
  }
}

/// Request storage permissions based on Android version
Future<void> _requestStoragePermissions(FeatureLogger logger) async {
  try {
    // For Android 13+ (API 33+), use granular media permissions
    if (await _isAndroid13OrHigher()) {
      // Request audio media permission for Android 13+
      final audioPermission = await Permission.audio.status;
      if (!audioPermission.isGranted) {
        final result = await Permission.audio.request();
        logger.i('Audio media permission: $result');
      }
    } else {
      // For older Android versions, use traditional storage permission
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final result = await Permission.storage.request();
        logger.i('Storage permission: $result');
      }
    }

    // Also check if we can write to external storage (optional fallback)
    final externalStorageStatus = await Permission.manageExternalStorage.status;
    logger.i('External storage permission: $externalStorageStatus');
    
  } catch (e) {
    logger.w('Storage permission check failed - app will use internal storage: $e');
  }
}

/// Check if device is running Android 13 (API 33) or higher
Future<bool> _isAndroid13OrHigher() async {
  try {
    // This is a simple check - in practice you might want to use device_info_plus
    // For now, we'll assume modern devices and handle permission fallbacks
    return true; // Default to modern permission handling
  } catch (e) {
    return false;
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
    return MaterialApp.router(
      title: 'GemmaTutor - AI Learning Assistant',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
    );
  }
}