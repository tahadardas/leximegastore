import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_merch_repository.dart';
import '../../domain/entities/admin_review.dart';

final adminReviewsControllerProvider =
    AsyncNotifierProviderFamily<
      AdminReviewsController,
      List<AdminReview>,
      String
    >(AdminReviewsController.new);

class AdminReviewsController
    extends FamilyAsyncNotifier<List<AdminReview>, String> {
  @override
  FutureOr<List<AdminReview>> build(String arg) {
    return _fetch();
  }

  Future<List<AdminReview>> _fetch() {
    return ref.read(adminMerchRepositoryProvider).getReviews(status: arg);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> updateStatus(int id, String newStatus) async {
    try {
      await ref
          .read(adminMerchRepositoryProvider)
          .updateReviewStatus(id: id, status: newStatus);

      // We refresh the list. If it was moved to another status,
      // it will naturally disappear from this list.
      await refresh();
    } catch (e) {
      // Re-throw to handle in UI if needed (toasts, etc.)
      rethrow;
    }
  }
}
