// lib/src/core/services/error_handler_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logger_service.dart';

class ErrorHandlerService {
  static final _logger = LoggerService.instance;

  static void init() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _logger.e('Flutter Error', error: details.exception, stackTrace: details.stack);

      // In production, you could send to a crash reporting service
      if (kReleaseMode) {
        // TODO: Add crash reporting service here (Firebase Crashlytics, etc.)
        _logger.e('Production error logged', error: details.exception);
      }
    };

    // Handle errors outside of Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      _logger.e('Platform Error', error: error, stackTrace: stack);

      if (kReleaseMode) {
        // TODO: Add crash reporting service here
        _logger.e('Production platform error logged', error: error);
      }

      return true;
    };
  }

  static void handleError(dynamic error, {String? context}) {
    final contextMsg = context != null ? ' in $context' : '';
    _logger.e('Error$contextMsg', error: error);

    if (kReleaseMode) {
      // TODO: Send to crash reporting service
      _logger.e('Production error handled', error: error);
    }
  }

  static void handleApiError(dynamic error, {String? context}) {
    final errorMessage = _extractErrorMessage(error);
    final contextMsg = context != null ? ' in $context' : '';
    _logger.e('API Error$contextMsg', error: error);

    // You can add custom handling based on error type
    if (error is NetworkException) {
      _logger.w('Network error detected: $errorMessage');
    } else if (error is AuthenticationException) {
      _logger.w('Authentication error detected: $errorMessage');
    }
  }

  static String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString();
    }
    return error?.toString() ?? 'Unknown error';
  }
}

// Custom exception classes
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

// Error handling mixin for widgets
mixin ErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  void handleError(dynamic error, {String? context}) {
    ErrorHandlerService.handleApiError(error, context: context);
  }

  void showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}