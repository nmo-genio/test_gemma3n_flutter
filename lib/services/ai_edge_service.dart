import 'package:flutter/services.dart';
import 'gemma_download_service.dart';

class AIEdgeService {
  static const MethodChannel _channel = MethodChannel('ai_edge_gemma');
  static bool _isInitialized = false;
  static String? _modelPath;

  /// Initialize Gemma 3n E4B model with Google AI Edge
  static Future<Map<String, dynamic>> initialize() async {
    try {
      if (_isInitialized) {
        return {'success': true, 'message': 'Already initialized'};
      }

      // Check if model is downloaded
      final isDownloaded = await GemmaDownloadService.isModelDownloaded();
      if (!isDownloaded) {
        return {
          'success': false,
          'error': 'Gemma 3n model not downloaded. Please download first.'
        };
      }

      // Get model path
      _modelPath = await GemmaDownloadService.getModelPath();

      // Initialize with platform channel
      final result = await _channel.invokeMethod('initialize', {
        'modelPath': _modelPath,
        'modelType': 'gemma-3n-e4b',
        'maxTokens': 512,
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'numThreads': 4,
      }) as Map<dynamic, dynamic>?;

      final resultMap = result?.cast<String, dynamic>() ?? <String, dynamic>{};

      if (resultMap['success'] == true) {
        _isInitialized = true;
        return {
          'success': true,
          'message': 'Gemma 3n E4B initialized successfully',
          'modelInfo': resultMap['modelInfo'] ?? {}
        };
      } else {
        return {
          'success': false,
          'error': resultMap['error'] ?? 'Unknown initialization error'
        };
      }

    } catch (e) {
      print('AI Edge initialization error: $e');
      return {
        'success': false,
        'error': 'Failed to initialize: $e'
      };
    }
  }

  /// Generate text using Gemma 3n
  static Future<Map<String, dynamic>> generateText(String prompt) async {
    if (!_isInitialized) {
      return {
        'success': false,
        'error': 'AI Edge not initialized. Call initialize() first.'
      };
    }

    if (prompt.trim().isEmpty) {
      return {
        'success': false,
        'error': 'Prompt cannot be empty'
      };
    }

    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;

      final result = await _channel.invokeMethod('generateText', {
        'prompt': prompt.trim(),
      }) as Map<dynamic, dynamic>?;

      final resultMap = result?.cast<String, dynamic>() ?? <String, dynamic>{};

      final endTime = DateTime.now().millisecondsSinceEpoch;
      final inferenceTime = endTime - startTime;

      if (resultMap['success'] == true) {
        final responseText = resultMap['text'] ?? 'No response generated';
        final tokenCount = responseText.split(' ').length;
        final tokensPerSecond = tokenCount / (inferenceTime / 1000);

        return {
          'success': true,
          'text': responseText,
          'inferenceTimeMs': inferenceTime,
          'tokenCount': tokenCount,
          'tokensPerSecond': tokensPerSecond.round(),
        };
      } else {
        return {
          'success': false,
          'error': resultMap['error'] ?? 'Text generation failed'
        };
      }
    } catch (e) {
      print('Text generation error: $e');
      return {
        'success': false,
        'error': 'Failed to generate text: $e'
      };
    }
  }

  /// Get current memory usage information
  static Future<Map<String, dynamic>> getMemoryUsage() async {
    try {
      final result = await _channel.invokeMethod('getMemoryUsage') as Map<dynamic, dynamic>?;
      final resultMap = result?.cast<String, dynamic>() ?? <String, dynamic>{};
      return {
        'totalMB': resultMap['totalMB'] ?? 0,
        'availableMB': resultMap['availableMB'] ?? 0,
        'usedMB': resultMap['usedMB'] ?? 0,
        'modelSizeMB': await GemmaDownloadService.getModelSizeMB(),
        'isUnder3GB': (resultMap['usedMB'] ?? 0) < 3072,
      };
    } catch (e) {
      print('Memory usage error: $e');
      return {
        'totalMB': 0,
        'availableMB': 0,
        'usedMB': 0,
        'modelSizeMB': 0,
        'isUnder3GB': true,
      };
    }
  }

  /// Get disk space information
  static Future<Map<String, dynamic>> getDiskSpace() async {
    try {
      final result = await _channel.invokeMethod('getDiskSpace') as Map<dynamic, dynamic>?;
      final resultMap = result?.cast<String, dynamic>() ?? <String, dynamic>{};
      return {
        'totalGB': resultMap['totalGB'] ?? 0,
        'availableGB': resultMap['availableGB'] ?? 0,
        'usedGB': resultMap['usedGB'] ?? 0,
        'freeSpacePercent': resultMap['freeSpacePercent'] ?? 0,
      };
    } catch (e) {
      print('Disk space error: $e');
      return {
        'totalGB': 32.0,
        'availableGB': 16.0,
        'usedGB': 16.0,
        'freeSpacePercent': 50.0,
      };
    }
  }

  // Add to your existing ai_edge_service.dart
  static Future<Map<String, dynamic>> getProcessorUtilization() async {
    try {
      final result = await _channel.invokeMethod('getProcessorUtilization') as Map<dynamic, dynamic>?;
      final resultMap = result?.cast<String, dynamic>() ?? <String, dynamic>{};

      return {
        'cpuUtilization': resultMap['cpuUtilization'] ?? 0.0,
        'gpuUtilization': resultMap['gpuUtilization'] ?? 0.0,
        'currentProcessingUnit': resultMap['currentProcessingUnit'] ?? 'CPU',
        'isGPUAvailable': resultMap['isGPUAvailable'] ?? false,
        'cpuCores': resultMap['cpuCores'] ?? 4,
        'thermalState': resultMap['thermalState'] ?? 'normal',
        'powerUsageWatts': resultMap['powerUsageWatts'] ?? 0.0,
      };
    } catch (e) {
      return {
        'cpuUtilization': 0.0,
        'gpuUtilization': 0.0,
        'currentProcessingUnit': 'CPU',
        'isGPUAvailable': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getPerformanceMetrics() async {
    try {
      final result = await _channel.invokeMethod('getPerformanceMetrics') as Map<dynamic, dynamic>?;
      final resultMap = result?.cast<String, dynamic>() ?? <String, dynamic>{};

      return {
        'avgInferenceTimeMs': resultMap['avgInferenceTimeMs'] ?? 0,
        'avgTokensPerSecond': resultMap['avgTokensPerSecond'] ?? 0,
        'totalInferences': resultMap['totalInferences'] ?? 0,
        'preferredProcessingUnit': resultMap['preferredProcessingUnit'] ?? 'CPU',
        'batteryOptimized': resultMap['batteryOptimized'] ?? false,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get detailed model and system information
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final memoryUsage = await getMemoryUsage();
      final modelInfo = await GemmaDownloadService.getModelInfo();

      Map<String, dynamic> systemInfo = {};

      if (_isInitialized) {
        final result = await _channel.invokeMethod('getSystemInfo') as Map<dynamic, dynamic>?;
        systemInfo = result?.cast<String, dynamic>() ?? <String, dynamic>{};
      }

      return {
        'isInitialized': _isInitialized,
        'modelPath': _modelPath,
        'modelInfo': modelInfo,
        'memoryUsage': memoryUsage,
        'systemInfo': systemInfo,
        'aiEdgeVersion': '1.0.0',
        'modelType': 'Gemma 3n E4B',
        'deviceSupported': true,
      };
    } catch (e) {
      print('System info error: $e');
      return {
        'isInitialized': _isInitialized,
        'error': 'Failed to get system info: $e'
      };
    }
  }

  /// Test the model with a simple prompt
  static Future<Map<String, dynamic>> testModel() async {
    const testPrompt = "Hello! Please respond with a brief greeting.";
    print('Testing model with prompt: $testPrompt');

    final result = await generateText(testPrompt);

    if (result['success'] == true) {
      print('✅ Model test successful');
      print('Response: ${result['text']}');
      print('Inference time: ${result['inferenceTimeMs']}ms');
      print('Tokens per second: ${result['tokensPerSecond']}');
    } else {
      print('❌ Model test failed: ${result['error']}');
    }

    return result;
  }

  /// Clean up and dispose resources
  static Future<void> dispose() async {
    try {
      if (_isInitialized) {
        await _channel.invokeMethod('dispose');
      }
    } catch (e) {
      print('Dispose error: $e');
    } finally {
      _isInitialized = false;
      _modelPath = null;
    }
  }

  /// Check if the service is initialized
  static bool get isInitialized => _isInitialized;

  /// Get the current model path
  static String? get modelPath => _modelPath;
}