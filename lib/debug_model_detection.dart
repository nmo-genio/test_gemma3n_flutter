// Debug utility to test model detection
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'services/gemma_download_service.dart';
import 'services/ai_edge_service.dart';
import 'src/core/services/logger_service.dart';

/// Debug utility to test model detection and initialization
class DebugModelDetection {
  static Future<void> testModelDetection() async {
    final logger = FeatureLogger('ModelDebug');
    
    try {
      logger.i('🔍 Testing model detection...');
      
      // Test 1: Check app_flutter directory structure
      final appDocsDir = await getApplicationDocumentsDirectory();
      logger.i('App documents directory: ${appDocsDir.path}');
      
      // Test 2: Check both possible model file locations
      final locations = [
        '${appDocsDir.path}/gemma-3n-E4B-it-int4.litertlm',
        '${appDocsDir.path}/gemma_3n_e4b_int4.litertlm',
        '/data/data/com.example.test_gemma3n_flutter/app_flutter/gemma-3n-E4B-it-int4.litertlm',
        '/data/data/com.example.test_gemma3n_flutter/app_flutter/gemma_3n_e4b_int4.litertlm',
      ];
      
      for (final location in locations) {
        final file = File(location);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        logger.i('📍 $location: exists=$exists, size=${size}MB');
      }
      
      // Test 3: Use GemmaDownloadService detection
      final isDownloaded = await GemmaDownloadService.isModelDownloaded();
      final modelInfo = await GemmaDownloadService.getModelInfo();
      
      logger.i('📊 GemmaDownloadService results:');
      logger.i('  - isDownloaded: $isDownloaded');
      logger.i('  - modelInfo: $modelInfo');
      
      // Test 4: Try to initialize if model exists
      if (isDownloaded) {
        logger.i('🚀 Attempting model initialization...');
        
        try {
          final result = await AIEdgeService.initialize(
            modelPath: modelInfo['path'],
            useGPU: false,
            maxTokens: 1024,
          );
          logger.i('✅ Initialization result: $result');
        } catch (e) {
          logger.e('❌ Initialization failed: $e');
        }
      }
      
    } catch (e, stackTrace) {
      logger.e('❌ Debug test failed', error: e, stackTrace: stackTrace);
    }
  }
}