import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/utils/relative_time.dart';
import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../shared/ui/lexi_alert.dart';
import '../../../../support/data/support_api.dart';
import '../../../../support/domain/entities/support_ticket.dart';

class AdminSupportInboxPage extends ConsumerStatefulWidget {
  const AdminSupportInboxPage({super.key});

  @override
  ConsumerState<AdminSupportInboxPage> createState() =>
      _AdminSupportInboxPageState();
}

class _AdminSupportInboxPageState extends ConsumerState<AdminSupportInboxPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _status = '';
  String _priority = '';
  String _category = '';
  String _assigned = '';

  List<SupportTicket> _tickets = const [];
  Map<String, dynamic> _analytics = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(supportApiProvider);
      final inbox = await api.getAdminTickets(
        status: _status,
        priority: _priority,
        category: _category,
        assigned: _assigned,
        q: _searchController.text.trim(),
      );
      Map<String, dynamic> analytics = const {};
      try {
        analytics = await api.getAnalytics(range: '7d');
      } catch (_) {
        analytics = const {};
      }

      if (!mounted) return;
      setState(() {
        _tickets = inbox.tickets;
        _analytics = analytics;
      });
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(
        context,
        text: 'تعذر تحميل صندوق الدعم.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'support_refresh',
        onPressed: _loading ? null : _load,
        child: const Icon(Icons.refresh),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(LexiSpacing.md),
                children: [
                  _AnalyticsStrip(analytics: _analytics),
                  const SizedBox(height: LexiSpacing.md),
                  _buildFilters(),
                  const SizedBox(height: LexiSpacing.md),
                  if (_tickets.isEmpty)
                    const Center(
                      child: Text(
                        'لا توجد تذاكر مطابقة حالياً.',
                      ),
                    ),
                  ..._tickets.map(
                    (ticket) => _AdminTicketCard(
                      ticket: ticket,
                      onTap: () => context.push('/admin/support/${ticket.id}'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'بحث برقم التذكرة أو الهاتف أو الموضوع',
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _drop(
                  title: 'الحالة',
                  value: _status,
                  items: const [
                    ('', 'الكل'),
                    ('open', 'مفتوحة'),
                    ('pending_admin', 'بانتظار الدعم'),
                    ('pending_customer', 'بانتظار العميل'),
                    ('in_progress', 'قيد المعالجة'),
                    ('resolved', 'تم الحل'),
                    ('closed', 'مغلقة'),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
                _drop(
                  title: 'الأولوية',
                  value: _priority,
                  items: const [
                    ('', 'الكل'),
                    ('low', 'منخفضة'),
                    ('medium', 'متوسطة'),
                    ('high', 'عالية'),
                    ('urgent', 'عاجلة'),
                  ],
                  onChanged: (v) => setState(() => _priority = v),
                ),
                _drop(
                  title: 'التصنيف',
                  value: _category,
                  items: const [
                    ('', 'الكل'),
                    ('shipping', 'الشحن'),
                    ('payment', 'الدفع'),
                    ('product', 'المنتجات'),
                    ('technical', 'تقني'),
                    ('other', 'أخرى'),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                _drop(
                  title: 'التعيين',
                  value: _assigned,
                  items: const [
                    ('', 'الكل'),
                    ('me', 'مُعيّنة لي'),
                    ('unassigned', 'غير مُعيّنة'),
                  ],
                  onChanged: (v) => setState(() => _assigned = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('تطبيق الفلاتر'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop({
    required String title,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: title),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(value: e.$1, child: Text(e.$2)),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }
}

class _AnalyticsStrip extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const _AnalyticsStrip({required this.analytics});

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _toText(dynamic v) => (v ?? '0').toString();

  @override
  Widget build(BuildContext context) {
    final open = _toInt(analytics['open_tickets_count']);
    final sla = _toInt(analytics['sla_breach_count']);
    final avg = _toText(analytics['avg_first_response_minutes']);
    final rating = _toText(analytics['rating_average']);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _kpi('تذاكر مفتوحة', '$open'),
        _kpi('تجاوز SLA', '$sla'),
        _kpi('متوسط أول رد (د)', avg),
        _kpi('متوسط التقييم', rating),
      ],
    );
  }

  Widget _kpi(String label, String value) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: LexiColors.neutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _AdminTicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _AdminTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(
          '${ticket.ticketNumber} - ${ticket.subject}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${ticket.name} - ${ticket.phone}'),
            const SizedBox(height: 4),
            Text(
              formatRelativeTimeFromString(
                ticket.createdAt,
                fallback: ticket.createdAt,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(ticket.priorityLabelAr),
                _chip(ticket.statusLabelAr),
                if (ticket.unreadCount > 0)
                  _chip('غير مقروء: ${ticket.unreadCount}'),
                if (ticket.firstResponseOverdue || ticket.resolutionOverdue)
                  _chip('تنبيه SLA', color: Colors.red.shade100),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _chip(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? LexiColors.neutral200,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
