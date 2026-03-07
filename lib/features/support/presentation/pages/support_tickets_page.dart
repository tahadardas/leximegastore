import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/app_session.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../auth/presentation/controllers/customer_auth_controller.dart';
import '../../data/local/support_ticket_store.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../../data/support_api.dart';
import '../widgets/create_support_ticket_sheet.dart';

class SupportTicketsPage extends ConsumerStatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  ConsumerState<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends ConsumerState<SupportTicketsPage> {
  bool _isLoading = true;
  List<LocalSupportTicket> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    final repo = ref.read(supportRepositoryProvider);
    final store = ref.read(supportTicketStoreProvider);

    try {
      final result = await repo.getMyTickets();

      await result.fold((failure) async {}, (remoteTickets) async {
        for (final t in remoteTickets) {
          await store.save(
            LocalSupportTicket(
              ticketId: t.id,
              ticketNumber: t.ticketNumber,
              chatToken: t.chatToken,
              subject: t.subject,
              status: t.status,
              statusLabelAr: t.statusLabel,
              phone: t.phone,
              updatedAt: t.updatedAt,
              createdAt: t.createdAt,
            ),
          );
        }
      });
    } catch (_) {
      // Keep local-only mode if remote load fails.
    }

    if (!mounted) {
      return;
    }

    final items = await store.getAll();

    if (!mounted) {
      return;
    }

    setState(() {
      _tickets = items;
      _isLoading = false;
    });

    if (!mounted) {
      return;
    }
    await _refreshStatuses(silent: true);
  }

  Future<void> _refreshStatuses({bool silent = false}) async {
    final store = ref.read(supportTicketStoreProvider);
    final api = ref.read(supportApiProvider);
    final current = await store.getAll();

    for (final local in current) {
      try {
        final details = await api.getTicketDetails(
          ticketId: local.ticketId,
          token: local.chatToken,
        );
        await store.save(
          local.copyWith(
            subject: details.ticket.subject,
            status: details.ticket.status,
            statusLabelAr: details.ticket.statusLabel,
            updatedAt: details.ticket.updatedAt.isNotEmpty
                ? details.ticket.updatedAt
                : DateTime.now().toIso8601String(),
          ),
        );
      } catch (_) {
        // Keep local status if refresh failed.
      }
    }

    final updated = await store.getAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _tickets = updated;
      if (!silent) {
        _isLoading = false;
      }
    });
  }

  Future<void> _openCreateTicket() async {
    final session = ref.read(appSessionProvider);
    final customer = ref.read(customerAuthControllerProvider).asData?.value;
    final displayName = (session.displayName ?? '').trim();
    final fallbackName = displayName.isNotEmpty ? displayName : 'عميل';

    await showCreateSupportTicketSheet(
      context: context,
      ref: ref,
      initialName: customer?.fullName.trim().isNotEmpty == true
          ? customer!.fullName
          : fallbackName,
      initialPhone: (customer?.phone ?? session.phone ?? '').trim(),
      initialEmail: (customer?.email ?? session.email ?? '').trim(),
    );

    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: const LexiAppBar(title: 'تذاكري'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.md,
              LexiSpacing.md,
              LexiSpacing.md,
              LexiSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCreateTicket,
                icon: const FaIcon(FontAwesomeIcons.plus, size: 15),
                label: const Text('إنشاء تذكرة'),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const _SupportTicketsSkeleton()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _tickets.isEmpty
                        ? _EmptySupportTickets(onCreateTap: _openCreateTicket)
                        : ListView.separated(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              LexiSpacing.md,
                              0,
                              LexiSpacing.md,
                              LexiSpacing.lg,
                            ),
                            itemCount: _tickets.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: LexiSpacing.sm),
                            itemBuilder: (context, index) {
                              final ticket = _tickets[index];
                              return Card(
                                child: ListTile(
                                  onTap: () {
                                    context.push(
                                      '/support/tickets/${ticket.ticketId}/chat?token=${Uri.encodeComponent(ticket.chatToken)}',
                                    );
                                  },
                                  title: Text(
                                    ticket.ticketNumber.isEmpty
                                        ? 'تذكرة #${ticket.ticketId}'
                                        : ticket.ticketNumber,
                                    style: LexiTypography.labelMd,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        ticket.subject,
                                        style: LexiTypography.bodyMd,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusChip(
                                            label: ticket.statusLabelAr,
                                          ),
                                          Text(
                                            formatRelativeTimeFromString(
                                              ticket.createdAt,
                                              fallback:
                                                  formatRelativeTimeFromString(
                                                    ticket.updatedAt,
                                                    fallback: ticket.updatedAt,
                                                  ),
                                            ),
                                            style: LexiTypography.caption,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'مشاركة',
                                        onPressed: () {
                                          ShareService.instance.shareTicketById(
                                            ticketId: ticket.ticketId,
                                          );
                                        },
                                        icon: const Icon(Icons.share_outlined),
                                      ),
                                      const FaIcon(
                                        FontAwesomeIcons.chevronLeft,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: LexiColors.brandPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: LexiTypography.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupportTicketsSkeleton extends StatelessWidget {
  const _SupportTicketsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(LexiSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: LexiSpacing.sm),
      itemBuilder: (_, index) => Container(
        height: 92,
        decoration: BoxDecoration(
          color: LexiColors.neutral200,
          borderRadius: BorderRadius.circular(LexiRadius.lg),
        ),
      ),
    );
  }
}

class _EmptySupportTickets extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptySupportTickets({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Center(
          child: FaIcon(
            FontAwesomeIcons.inbox,
            size: 40,
            color: LexiColors.neutral500,
          ),
        ),
        const SizedBox(height: LexiSpacing.sm),
        Center(child: Text('لا توجد تذاكر بعد', style: LexiTypography.labelLg)),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'أنشئ تذكرة جديدة وسيتم الرد عليك بأسرع وقت.',
            style: LexiTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: LexiSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.lg),
          child: ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
            label: const Text('إنشاء تذكرة'),
          ),
        ),
      ],
    );
  }
}
