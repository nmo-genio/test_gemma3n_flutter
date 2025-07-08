// services/ai_edge_service.dart - Updated for real LiteRT-LM integration
import 'package:flutter/services.dart';
import '../src/core/services/logger_service.dart';

/// Service class for interacting with Gemma 3n E4B model via LiteRT-LM
/// Provides methods for model initialization and text generation
class AIEdgeService {
  static const MethodChannel _channel = MethodChannel('ai_edge_gemma');

  /// Initialize the Gemma 3n E4B model with LiteRT-LM runtime
  ///
  /// [modelPath] - Optional custom path to the .litertlm model file
  /// [useGPU] - Whether to prefer GPU acceleration (defaults to false for compatibility)
  /// [maxTokens] - Maximum tokens for input + output combined (default: 2048)
  ///
  /// Returns: Map with initialization results
  static Future<Map<String, dynamic>> initialize({
    String? modelPath,
    bool useGPU = false,
    int maxTokens = 2048,
  }) async {
    try {
      LoggerService.i('🚀 Initializing Gemma 3n E4B model...');
      LoggerService.d('Parameters: GPU=$useGPU, MaxTokens=$maxTokens');

      final result = await _channel.invokeMethod('initialize', {
        if (modelPath != null) 'modelPath': modelPath,
        'useGPU': useGPU,
        'maxTokens': maxTokens,
      });

      LoggerService.i('✅ Model initialization completed');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      LoggerService.e('❌ Model initialization failed: $e');
      rethrow;
    }
  }

  /// Generate text using the Gemma 3n model via LiteRT-LM
  ///
  /// [prompt] - Input text prompt for generation
  /// [temperature] - Controls randomness (0.0-1.0, higher = more creative)
  /// [topK] - Limits sampling to top K tokens (default: 40)
  /// [topP] - Nucleus sampling probability threshold (default: 0.95)
  ///
  /// Returns: Generated text response
  static Future<String> generateText(
      String prompt, {
        double temperature = 0.8,
        int topK = 40,
        double topP = 0.95,
      }) async {
    try {
      if (prompt.trim().isEmpty) {
        throw ArgumentError('Prompt cannot be empty');
      }

      LoggerService.i('🤖 Generating text with Gemma 3n...');
      LoggerService.d('Prompt: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');
      LoggerService.d('Params: temp=$temperature, topK=$topK, topP=$topP');

      final stopwatch = Stopwatch()..start();

      final result = await _channel.invokeMethod('generateText', {
        'prompt': prompt,
        'temperature': temperature,
        'topK': topK,
        'topP': topP,
      });

      stopwatch.stop();
      LoggerService.i('✅ Text generated in ${stopwatch.elapsedMilliseconds}ms');

      return result as String;
    } catch (e) {
      LoggerService.e('❌ Text generation failed: $e');
      rethrow;
    }
  }

  /// Get current memory usage information
  static Future<Map<String, dynamic>> getMemoryUsage() async {
    try {
      final result = await _channel.invokeMethod('getMemoryUsage');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      LoggerService.e('Failed to get memory usage: $e');
      rethrow;
    }
  }

  /// Get disk space information
  static Future<Map<String, dynamic>> getDiskSpace() async {
    try {
      final result = await _channel.invokeMethod('getDiskSpace');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      LoggerService.e('Failed to get disk space: $e');
      rethrow;
    }
  }

  /// Get system information
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final result = await _channel.invokeMethod('getSystemInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      LoggerService.e('Failed to get system info: $e');
      rethrow;
    }
  }

  /// Get performance metrics
  static Future<Map<String, dynamic>> getPerformanceMetrics() async {
    try {
      final result = await _channel.invokeMethod('getPerformanceMetrics');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      LoggerService.e('Failed to get performance metrics: $e');
      rethrow;
    }
  }

  /// Get processor utilization
  static Future<Map<String, dynamic>> getProcessorUtilization() async {
    try {
      final result = await _channel.invokeMethod('getProcessorUtilization');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      LoggerService.e('Failed to get processor utilization: $e');
      rethrow;
    }
  }

  /// Dispose of the model and free memory
  static Future<bool> dispose() async {
    try {
      LoggerService.i('🗑️ Disposing Gemma model...');
      final result = await _channel.invokeMethod('dispose');
      LoggerService.i('✅ Model disposed successfully');
      return result as bool;
    } catch (e) {
      LoggerService.e('Failed to dispose model: $e');
      rethrow;
    }
  }

  /// Generate text and return structured response for UI compatibility
  /// Returns: Map with success, text, error, and metrics
  static Future<Map<String, dynamic>> generateTextWithMetrics(
      String prompt, {
        double temperature = 0.8,
        int topK = 40,
        double topP = 0.95,
      }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final text = await generateText(prompt, temperature: temperature, topK: topK, topP: topP);
      stopwatch.stop();
      
      return {
        'success': true,
        'text': text,
        'inferenceTimeMs': stopwatch.elapsedMilliseconds,
        'tokensPerSecond': (text.split(' ').length / (stopwatch.elapsedMilliseconds / 1000)).round(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'text': '',
        'inferenceTimeMs': 0,
        'tokensPerSecond': 0,
      };
    }
  }

  /// Legacy method for backward compatibility
  /// Wraps the new generateText method
  static Future<String> runInference(String prompt) async {
    return generateText(prompt);
  }
}

// ===============================
// LESSON ANALYSIS SERVICE
// ===============================

/// Service specifically for analyzing lesson transcripts with Gemma 3n
class LessonAnalysisService {
  /// Analyzes a lesson transcript and provides educational feedback
  static Future<String> analyzeLessonTranscript(String transcript) async {
    final prompt = '''
Analyze this lesson transcript and provide constructive educational feedback:

LESSON TRANSCRIPT:
$transcript

Please provide:
1. Key learning objectives covered
2. Teaching effectiveness assessment
3. Student engagement opportunities
4. Specific suggestions for improvement
5. Areas that might need clarification

Format your response to be helpful for the teacher.
''';

    return await AIEdgeService.generateText(
      prompt,
      temperature: 0.7, // Balanced creativity for educational feedback
      topK: 40,
      topP: 0.9,
    );
  }

  /// Generates follow-up questions based on lesson content
  static Future<String> generateFollowUpQuestions(String transcript) async {
    final prompt = '''
Based on this lesson transcript, generate 5 thoughtful questions that students might ask:

LESSON CONTENT:
$transcript

Provide questions that:
- Test understanding of key concepts
- Encourage critical thinking
- Relate to real-world applications
- Help identify knowledge gaps
''';

    return await AIEdgeService.generateText(prompt, temperature: 0.8);
  }

  /// Creates a lesson summary
  static Future<String> createLessonSummary(String transcript) async {
    final prompt = '''
Create a concise summary of this lesson for review purposes:

LESSON TRANSCRIPT:
$transcript

Include:
- Main topics covered
- Key concepts explained
- Important takeaways
- Next steps for students
''';

    return await AIEdgeService.generateText(prompt, temperature: 0.6);
  }
}
