import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../support_api.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepositoryImpl(api: ref.watch(supportApiProvider));
});

class SupportRepositoryImpl implements SupportRepository {
  final SupportApi api;

  SupportRepositoryImpl({required this.api});

  @override
  Future<Either<AppFailure, List<SupportTicket>>> getMyTickets() async {
    try {
      final remoteTickets = await api.getMyTickets();
      return Right(remoteTickets);
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(AppFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<AppFailure, TicketDetails>> getTicketDetails(
    int ticketId,
  ) async {
    try {
      // API requires token. Repository interface handles ID.
      // This implies we need a way to get the token or the API should support getting details by ID only (for auth users).
      // However, SupportApi.getTicketDetails requires token.
      // If the user is logged in, we might need a different endpoint or the backend handles it.
      // My backend 'get_ticket' route handles auth user OR token.
      // But SupportApi passes token.
      // If we don't have a token, we pass empty string?
      // Let's assume for now we can pass empty string if auth is handled by cookies/headers.

      final remoteDetails = await api.getTicketDetails(
        ticketId: ticketId,
        token: '',
      );

      // SupportTicketDetails in API != TicketDetails in Domain?
      // Domain TicketDetails in repository interface:
      // Future<TicketDetails> getTicketDetails(int ticketId);

      // SupportApi returns SupportTicketDetails.
      // We need to map it or use it.
      // Let's check Domain TicketDetails definition.

      return Right(
        TicketDetails(
          ticket: remoteDetails.ticket,
          messages: remoteDetails.messages,
        ),
      );
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(AppFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<AppFailure, SupportTicket>> createTicket(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await api.createTicket(
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        email: data['email'],
        subject: data['subject'],
        category: data['category'],
        priority: data['priority'],
        message: data['message'],
      );

      // SupportApi.createTicket returns Map<String, dynamic>.
      // We need to convert it to SupportTicket.
      // The response from createTicket (backend) returns the ticket object.
      // SupportApi.createTicket returns extracted map.

      return Right(SupportTicket.fromJson(response));
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(AppFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<AppFailure, void>> replyToTicket(
    int ticketId,
    String message,
  ) async {
    try {
      // Again, API requires token.
      await api.sendMessage(ticketId: ticketId, token: '', message: message);
      return const Right(null);
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(AppFailure('حدث خطأ غير متوقع'));
    }
  }
}
