import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class GemmaDownloadService {
  static const MethodChannel _channel = MethodChannel('gemma_download');
  // static const String modelUrl = 'https://huggingface.co/google/gemma-3n-E4B-it-litert-lm-preview/resolve/main/model.tflite';
  // static const String modelFileName = 'gemma_3n_e4b_model.tflite';

  static const String modelUrl = 'https://huggingface.co/google/gemma-3n-E4B-it-litert-lm-preview/resolve/main/gemma-3n-E4B-it-int4.litertlm';
  static const String modelFileName = 'gemma-3n-E4B-it-int4.litertlm';


  static Future<bool> isModelDownloaded() async {
    try {
      // First, try to use the platform channel to check model status
      try {
        final result = await _channel.invokeMethod('isModelDownloaded');
        if (result['isDownloaded'] == true) {
          return true;
        }
      } catch (e) {
        // Fall back to direct file check if platform channel fails
      }
      
      // Direct file check as fallback
      final modelPath = await getModelPath();
      final file = File(modelPath);
      final exists = await file.exists();
      
      if (exists) {
        final size = await file.length();
        // Check if file size is reasonable (at least 1GB for E4B model)
        return size > (1024 * 1024 * 1024); // 1GB minimum
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> downloadModel({
    required Function(double) onProgress,
    required Function(String) onComplete,
    required Function(String) onError,
  }) async {
    try {
      final modelPath = await getModelPath();
      
      // Check if already downloaded
      if (await isModelDownloaded()) {
        onComplete(modelPath);
        return;
      }

      // Use platform channel to download with native implementation
      final result = await _channel.invokeMethod('downloadModel', {
        'url': modelUrl,
        'filePath': modelPath,
      });

      if (result['success'] == true) {
        onComplete(modelPath);
      } else {
        onError(result['error'] ?? 'Download failed');
      }
    } catch (e) {
      onError('Download failed: $e');
    }
  }

  static Future<String> getModelPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$modelFileName';
    } catch (e) {
      throw Exception('Failed to get model path: $e');
    }
  }

  static Future<double> getModelSizeMB() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return 1228.8; // Default E4B model size
    } catch (e) {
      return 1228.8; // Default E4B model size
    }
  }

  static Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      final actualSizeMB = await getModelSizeMB();
      
      return {
        'modelType': 'Gemma 3n E4B',
        'modelSizeMB': actualSizeMB,
        'numThreads': 4,
        'version': '1.0.0',
        'path': modelPath,
        'exists': await file.exists(),
        'url': modelUrl,
      };
    } catch (e) {
      return {
        'modelType': 'Gemma 3n E4B',
        'modelSizeMB': 1228.8,
        'numThreads': 4,
        'version': '1.0.0',
        'error': e.toString(),
      };
    }
  }

  static Future<void> deleteModel() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete model: $e');
    }
  }

  static Future<Map<String, dynamic>> getDownloadProgress() async {
    try {
      final result = await _channel.invokeMethod('getDownloadProgress');
      return result.cast<String, dynamic>();
    } catch (e) {
      return {
        'isDownloading': false,
        'progress': 0.0,
        'error': e.toString(),
      };
    }
  }
}