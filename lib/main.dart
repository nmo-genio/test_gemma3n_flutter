// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/core/services/logger_service.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/services/error_handler_service.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/routing/app_router.dart';
import 'services/ai_edge_service.dart';
import 'services/gemma_download_service.dart';

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

  // Initialize AI model if available
  await _initializeAIModelIfAvailable();
  logger.i('🤖 AI model initialization check completed');

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

/// Initialize AI model if it's already downloaded
Future<void> _initializeAIModelIfAvailable() async {
  final logger = FeatureLogger('AI_Init');
  
  try {
    logger.i('🔍 Checking if Gemma 3n model is downloaded...');
    
    // Check if model is downloaded using both platform channel and direct file check
    final isDownloaded = await GemmaDownloadService.isModelDownloaded();
    final modelInfo = await GemmaDownloadService.getModelInfo();
    final filePath = modelInfo['path'] as String? ?? '';
    final fileExists = modelInfo['exists'] as bool? ?? false;
    final modelSizeMB = modelInfo['modelSizeMB'] as double? ?? 0.0;
    
    logger.i('Model download status: $isDownloaded');
    logger.i('Model file path: $filePath');
    logger.i('Model file exists: $fileExists');
    logger.i('Model file size: ${modelSizeMB.toStringAsFixed(1)} MB');
    
    // Check if model exists and is at least 900MB (for Gemma 3n E4B)
    if (isDownloaded && fileExists && modelSizeMB > 900.0) {
      logger.i('✅ Model found, initializing Gemma 3n...');
      
      // Initialize the AI model with the correct path
      final initResult = await AIEdgeService.initialize(
        useGPU: false, // Start with CPU for compatibility
        maxTokens: 2048,
        modelPath: filePath, // Use the actual model path
      );
      
      if (initResult['success'] == true) {
        logger.i('🎉 Gemma 3n model initialized successfully!');
        logger.i('Backend: ${initResult['backend']}');
        logger.i('Model path: ${initResult['modelPath']}');
      } else {
        logger.w('⚠️ Model initialization failed: ${initResult['message']}');
        logger.w('Error: ${initResult['error']}');
        
        // Try alternative initialization approaches
        await _tryAlternativeInitialization(logger, filePath);
      }
    } else {
      if (!isDownloaded) {
        logger.i('📥 Model not downloaded yet - initialization skipped');
      } else if (!fileExists) {
        logger.w('⚠️ Model file does not exist at path: $filePath');
      } else {
        logger.w('⚠️ Model file appears incomplete (${modelSizeMB.toStringAsFixed(1)} MB) - initialization skipped');
        logger.w('Expected size: ~997MB for Gemma 3n E4B');
      }
    }
    
  } catch (e, stackTrace) {
    logger.e('❌ Error during AI model initialization', error: e, stackTrace: stackTrace);
    // Don't throw - app should continue even if AI init fails
  }
}

/// Try alternative initialization approaches if the primary fails
Future<void> _tryAlternativeInitialization(FeatureLogger logger, String filePath) async {
  try {
    logger.i('🔄 Trying alternative initialization approaches...');
    
    // Try with different GPU settings
    final initResult2 = await AIEdgeService.initialize(
      useGPU: true, // Try with GPU
      maxTokens: 1024, // Reduce tokens for memory
      modelPath: filePath,
    );
    
    if (initResult2['success'] == true) {
      logger.i('✅ Alternative initialization succeeded with GPU');
      return;
    }
    
    // Try with minimal settings
    final initResult3 = await AIEdgeService.initialize(
      useGPU: false,
      maxTokens: 512, // Minimal token count
      modelPath: filePath,
    );
    
    if (initResult3['success'] == true) {
      logger.i('✅ Alternative initialization succeeded with minimal settings');
      return;
    }
    
    logger.w('⚠️ All initialization attempts failed');
    
  } catch (e) {
    logger.e('❌ Alternative initialization failed', error: e);
  }
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