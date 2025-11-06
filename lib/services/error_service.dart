import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'dart:async';

/// Service for handling and logging errors throughout the application
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Initialize global error handlers
  void initialize() {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logError(
        details.exception,
        stackTrace: details.stack,
        context: 'Flutter Framework Error',
      );
    };

    // Catch errors outside of Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      logError(
        error,
        stackTrace: stack,
        context: 'Platform Error',
      );
      return true;
    };
  }

  /// Log an error with context
  void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorMessage = StringBuffer();

    if (context != null) {
      errorMessage.writeln('Context: $context');
    }

    errorMessage.writeln('Error: $error');

    if (additionalData != null && additionalData.isNotEmpty) {
      errorMessage.writeln('Additional Data:');
      additionalData.forEach((key, value) {
        errorMessage.writeln('  $key: $value');
      });
    }

    _logger.e(
      errorMessage.toString(),
      error: error,
      stackTrace: stackTrace,
    );

    // In production, you might want to send errors to a remote service
    // like Sentry, Firebase Crashlytics, etc.
    if (kReleaseMode) {
      _sendToRemoteLogging(error, stackTrace, context, additionalData);
    }
  }

  /// Log a warning
  void logWarning(String message, {Map<String, dynamic>? data}) {
    _logger.w(message, error: data);
  }

  /// Log an info message
  void logInfo(String message, {Map<String, dynamic>? data}) {
    _logger.i(message, error: data);
  }

  /// Log a debug message
  void logDebug(String message, {Map<String, dynamic>? data}) {
    _logger.d(message, error: data);
  }

  /// Send error to remote logging service (placeholder)
  void _sendToRemoteLogging(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  ) {
    // TODO: Implement remote logging service integration
    // Examples: Sentry, Firebase Crashlytics, custom API
    debugPrint('Would send to remote logging: $error');
  }

  /// Get user-friendly error message
  String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString().toLowerCase();

    // Database errors
    if (errorString.contains('sqlite') ||
        errorString.contains('database') ||
        errorString.contains('drift')) {
      return 'Database error. Please try again or contact support.';
    }

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network connection error. Please check your internet and try again.';
    }

    // File system errors
    if (errorString.contains('file') ||
        errorString.contains('directory') ||
        errorString.contains('path')) {
      return 'File system error. Please check storage permissions.';
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return 'Permission denied. Please grant necessary permissions.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    }

    // Format errors
    if (errorString.contains('format') ||
        errorString.contains('parse') ||
        errorString.contains('invalid')) {
      return 'Invalid data format. Please check your input.';
    }

    // Not found errors
    if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return 'Resource not found. Please refresh and try again.';
    }

    // Default message
    return 'An error occurred: ${error.toString()}';
  }

  /// Handle async operation with error logging
  Future<T?> handleAsync<T>({
    required Future<T> Function() operation,
    required String context,
    T? defaultValue,
    bool showUserMessage = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace: stackTrace,
        context: context,
      );
      return defaultValue;
    }
  }

  /// Wrap a function with error handling
  T? handleSync<T>({
    required T Function() operation,
    required String context,
    T? defaultValue,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      logError(
        error,
        stackTrace: stackTrace,
        context: context,
      );
      return defaultValue;
    }
  }
}

/// Error types for categorization
enum ErrorType {
  database,
  network,
  fileSystem,
  permission,
  validation,
  business,
  unknown,
}

/// Custom app exception
class AppException implements Exception {
  final String message;
  final ErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? additionalData;

  AppException({
    required this.message,
    this.type = ErrorType.unknown,
    this.originalError,
    this.stackTrace,
    this.additionalData,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AppException: $message');
    if (originalError != null) {
      buffer.write(' (Original: $originalError)');
    }
    return buffer.toString();
  }
}

/// Database-specific exception
class DatabaseException extends AppException {
  DatabaseException({
    required super.message,
    super.originalError,
    super.stackTrace,
    super.additionalData,
  }) : super(type: ErrorType.database);
}

/// Network-specific exception
class NetworkException extends AppException {
  NetworkException({
    required super.message,
    super.originalError,
    super.stackTrace,
    super.additionalData,
  }) : super(type: ErrorType.network);
}

/// Validation exception
class ValidationException extends AppException {
  ValidationException({
    required super.message,
    super.originalError,
    super.stackTrace,
    super.additionalData,
  }) : super(type: ErrorType.validation);
}

/// Business logic exception
class BusinessException extends AppException {
  BusinessException({
    required super.message,
    super.originalError,
    super.stackTrace,
    super.additionalData,
  }) : super(type: ErrorType.business);
}
