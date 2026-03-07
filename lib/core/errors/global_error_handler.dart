import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'arabic_error_mapper.dart';

/// Global error state with user-friendly Arabic messaging.
class GlobalErrorState {
  final String? message;
  final DateTime? timestamp;

  const GlobalErrorState({this.message, this.timestamp});
}

class GlobalErrorNotifier extends Notifier<GlobalErrorState> {
  @override
  GlobalErrorState build() => const GlobalErrorState();

  /// Map and push a new error to the UI.
  void pushError(Object error, {String? fallback}) {
    final message = ArabicErrorMapper.map(
      error,
      fallback: fallback ?? 'حدث خطأ غير متوقع.',
    );
    state = GlobalErrorState(message: message, timestamp: DateTime.now());
  }

  /// Clear the current error state.
  void clear() {
    state = const GlobalErrorState();
  }
}

/// Provider for global error management.
final globalErrorProvider =
    NotifierProvider<GlobalErrorNotifier, GlobalErrorState>(() {
      return GlobalErrorNotifier();
    });
