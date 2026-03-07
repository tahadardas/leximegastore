import 'package:dartz/dartz.dart';
import '../../../../core/errors/app_failure.dart';
import '../entities/support_ticket.dart';

abstract class SupportRepository {
  Future<Either<AppFailure, List<SupportTicket>>> getMyTickets();
  Future<Either<AppFailure, TicketDetails>> getTicketDetails(int ticketId);
  Future<Either<AppFailure, SupportTicket>> createTicket(
    Map<String, dynamic> data,
  );
  Future<Either<AppFailure, void>> replyToTicket(int ticketId, String message);
}
