import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../../data/repositories/support_repository_impl.dart';

final supportControllerProvider =
    StateNotifierProvider<SupportController, AsyncValue<List<SupportTicket>>>((
      ref,
    ) {
      return SupportController(ref.watch(supportRepositoryProvider));
    });

class SupportController extends StateNotifier<AsyncValue<List<SupportTicket>>> {
  final SupportRepository _repository;

  SupportController(this._repository) : super(const AsyncLoading()) {
    getTickets();
  }

  Future<void> getTickets() async {
    state = const AsyncLoading();
    final result = await _repository.getMyTickets();
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (tickets) => state = AsyncData(tickets),
    );
  }

  Future<void> refresh() async {
    await getTickets();
  }
}
