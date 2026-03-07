import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/submission_lock_service.dart';

/// Centralized submit locks to avoid duplicate critical actions.
class SubmitLocks {
  static const _checkoutKey = 'checkout:place-order';
  final SubmissionLockService _locks;

  SubmitLocks(this._locks);

  bool get isCheckoutLocked => _locks.isLocked(_checkoutKey);

  Future<T?> runCheckoutSubmit<T>(Future<T> Function() action) async {
    return _locks.run<T>(key: _checkoutKey, action: action);
  }

  Future<T?> runShamCashProofUpload<T>({
    required String orderId,
    required Future<T> Function() action,
  }) async {
    final key = orderId.trim();
    if (key.isEmpty) {
      return action();
    }
    return _locks.run<T>(key: 'shamcash:proof:$key', action: action);
  }
}

final submitLocksProvider = Provider<SubmitLocks>((ref) {
  return SubmitLocks(ref.watch(submissionLockServiceProvider));
});
