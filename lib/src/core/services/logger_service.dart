import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class LoggerService {
  static Logger? _instance;

  static Logger get instance {
    _instance ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: kDebugMode ? Level.debug : Level.info,
    );
    return _instance!;
  }

  static void init() {
    _instance = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: kDebugMode ? Level.debug : Level.info,
    );
  }

  // Convenience methods
  static void d(dynamic message) => instance.d(message);
  static void i(dynamic message) => instance.i(message);
  static void w(dynamic message) => instance.w(message);
  static void e(dynamic message, {Object? error, StackTrace? stackTrace}) {
    instance.e(message, error: error, stackTrace: stackTrace);
  }
}

// Feature-specific logger
class FeatureLogger {
  final Logger _logger;
  final String _feature;

  FeatureLogger(this._feature) : _logger = LoggerService.instance;

  void d(dynamic message) => _logger.d('[$_feature] $message');
  void i(dynamic message) => _logger.i('[$_feature] $message');
  void w(dynamic message) => _logger.w('[$_feature] $message');
  void e(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.e('[$_feature] $message', error: error, stackTrace: stackTrace);
  }
}