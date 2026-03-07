import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logging_config.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 110,
      colors: false,
      printEmojis: false,
    ),
  );

  static bool _initialized = false;
  static bool _sentryReady = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (LoggingConfig.sentryEnabled) {
      await SentryFlutter.init((options) {
        options.dsn = LoggingConfig.sentryDsn;
        options.environment = LoggingConfig.environment;
        options.release = LoggingConfig.appVersion;
        options.tracesSampleRate = 0.1;
        options.sendDefaultPii = false;
      }, appRunner: () {});
      _sentryReady = true;
    }

    await _setDefaultContext();
  }

  static Future<void> _setDefaultContext() async {
    if (!_sentryReady) {
      return;
    }

    await Sentry.configureScope((scope) {
      scope.setTag('environment', LoggingConfig.environment);
      scope.setTag('app_version', LoggingConfig.appVersion);
      scope.setContexts('device', {
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'mode': kReleaseMode ? 'release' : 'debug',
      });
    });
  }

  static void info(String message, {Map<String, dynamic>? extra}) {
    final clean = sanitizeExtra(extra);
    _logger.i(_compose(message, clean));

    if (_sentryReady && clean.isNotEmpty) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'app.info',
          level: SentryLevel.info,
          message: message,
          data: clean,
        ),
      );
    }
  }

  static void warn(String message, {Map<String, dynamic>? extra}) {
    final clean = sanitizeExtra(extra);
    _logger.w(_compose(message, clean));

    if (_sentryReady) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'app.warn',
          level: SentryLevel.warning,
          message: message,
          data: clean,
        ),
      );
    }
  }

  static Future<void> error(
    String message,
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic>? extra,
  }) async {
    final clean = sanitizeExtra(extra);
    _logger.e(_compose(message, clean), error: error, stackTrace: stackTrace);

    if (!_sentryReady) {
      return;
    }

    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = SentryLevel.error;
        scope.setContexts('extra', clean);
        scope.setTag('message', _truncate(message));
      },
    );
  }

  static String maskPhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 8) {
      return value;
    }
    final prefix = cleaned.substring(0, 2);
    final suffix = cleaned.substring(cleaned.length - 2);
    return '$prefix******$suffix';
  }

  static Map<String, dynamic> sanitizeExtra(Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) {
      return const {};
    }

    final output = <String, dynamic>{};
    extra.forEach((key, value) {
      output[key] = _sanitizeValue(value, key: key);
    });
    return output;
  }

  static dynamic _sanitizeValue(dynamic value, {String? key}) {
    final normalizedKey = (key ?? '').toLowerCase();

    if (value == null) {
      return null;
    }

    if (_isSensitiveKey(normalizedKey)) {
      if (normalizedKey.contains('phone')) {
        return maskPhone(value.toString());
      }
      return '***';
    }

    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), _sanitizeValue(v, key: k.toString())),
      );
    }

    if (value is List) {
      return value.map((item) => _sanitizeValue(item)).toList(growable: false);
    }

    if (value is Uri) {
      return _pathOnly(value.toString());
    }

    final text = value.toString();
    if (normalizedKey.contains('phone')) {
      return maskPhone(text);
    }

    var sanitized = text.replaceAllMapped(
      RegExp(r'\b09\d{8}\b'),
      (match) => maskPhone(match.group(0)!),
    );

    sanitized = sanitized.replaceAllMapped(
      RegExp(r'https?://[^\s]+'),
      (match) => _pathOnly(match.group(0)!),
    );

    return _truncate(sanitized);
  }

  static bool _isSensitiveKey(String key) {
    const sensitive = <String>[
      'password',
      'pass',
      'token',
      'authorization',
      'auth',
      'secret',
      'cookie',
      'set-cookie',
      'bearer',
    ];
    return sensitive.any((element) => key.contains(element));
  }

  static String _compose(String message, Map<String, dynamic> extra) {
    if (extra.isEmpty) {
      return message;
    }
    return '$message | ${jsonEncode(extra)}';
  }

  static String _truncate(String value, {int max = 400}) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...';
  }

  static String _pathOnly(String urlOrPath) {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }

    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri.path.isEmpty ? '/' : uri.path;
    }

    return uri.path.isEmpty ? trimmed : uri.path;
  }
}
