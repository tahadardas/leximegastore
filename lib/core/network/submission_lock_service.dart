import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deduplicates critical submissions by key.
///
/// If a key is already running, callers receive the same in-flight future.
class SubmissionLockService {
  final Map<String, Future<dynamic>> _inFlightByKey =
      <String, Future<dynamic>>{};

  bool isLocked(String key) {
    return _inFlightByKey.containsKey(_normalizeKey(key));
  }

  Future<T> run<T>({
    required String key,
    required Future<T> Function() action,
  }) {
    final normalized = _normalizeKey(key);
    final existing = _inFlightByKey[normalized];
    if (existing != null) {
      return existing as Future<T>;
    }

    final future = Future<T>.sync(action);
    _inFlightByKey[normalized] = future;

    if (kDebugMode) {
      debugPrint(
        '[SubmissionLock] acquired key=$normalized active=${_inFlightByKey.length}',
      );
    }

    future.whenComplete(() {
      _inFlightByKey.remove(normalized);
      if (kDebugMode) {
        debugPrint(
          '[SubmissionLock] released key=$normalized active=${_inFlightByKey.length}',
        );
      }
    });

    return future;
  }

  String _normalizeKey(String key) {
    return key.trim().toLowerCase();
  }
}

final submissionLockServiceProvider = Provider<SubmissionLockService>((ref) {
  return SubmissionLockService();
});
