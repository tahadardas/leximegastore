import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../shared/ui/lexi_alert.dart';
import '../../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../support/data/support_api.dart';
import '../../../../support/domain/entities/support_attachment.dart';
import '../../../../support/domain/entities/support_message.dart';
import '../../../../support/domain/entities/support_ticket.dart';

class AdminSupportTicketPage extends ConsumerStatefulWidget {
  final int ticketId;

  const AdminSupportTicketPage({super.key, required this.ticketId});

  @override
  ConsumerState<AdminSupportTicketPage> createState() =>
      _AdminSupportTicketPageState();
}

class _AdminSupportTicketPageState
    extends ConsumerState<AdminSupportTicketPage> {
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _assignController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _saving = false;
  bool _savingNote = false;

  String _status = '';
  String _priority = '';
  String _category = '';

  List<String> _cannedReplies = const [];
  SupportTicket? _ticket;
  List<SupportMessage> _messages = const [];
  List<SupportAttachment> _attachments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _noteController.dispose();
    _assignController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(supportApiProvider);
      final details = await api.getAdminTicketDetails(widget.ticketId);
      List<String> canned = const [];
      try {
        canned = await api.getCannedReplies();
      } catch (_) {
        canned = const [];
      }

      if (!mounted) return;
      setState(() {
        _ticket = details.ticket;
        _messages = details.messages;
        _attachments = details.attachments;
        _cannedReplies = canned;
        _status = details.ticket.status;
        _priority = details.ticket.priority;
        _category = details.ticket.category;
        _assignController.text =
            (details.ticket.assignedUserId != null &&
                details.ticket.assignedUserId! > 0)
            ? details.ticket.assignedUserId.toString()
            : '';
        _tagsController.text = details.ticket.tags.join(', ');
      });
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(
        context,
        text: _safeError(e, 'تعذر تحميل التذكرة.'),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendReply({bool asNote = false}) async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(supportApiProvider)
          .adminReply(ticketId: widget.ticketId, message: text, asNote: asNote);

      _replyController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text(asNote ? 'تم حفظ الملاحظة.' : 'تم إرسال الرد.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(context, text: _safeError(e, 'تعذر إرسال الرد.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(supportApiProvider);
      await api.adminUpdateTicket(
        ticketId: widget.ticketId,
        status: _status,
        priority: _priority,
        category: _category,
        tags: _tagsController.text.trim(),
      );

      final assignId = int.tryParse(_assignController.text.trim()) ?? 0;
      await api.adminAssign(
        ticketId: widget.ticketId,
        assignedUserId: assignId,
      );

      if (!mounted) return;
      await LexiAlert.success(context, text: 'تم حفظ التعديلات.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(
        context,
        text: _safeError(e, 'تعذر حفظ التعديلات.'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addInternalNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty || _savingNote) return;

    setState(() => _savingNote = true);
    try {
      await ref
          .read(supportApiProvider)
          .adminNote(ticketId: widget.ticketId, note: note);
      _noteController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('تم حفظ الملاحظة الداخلية.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(context, text: _safeError(e, 'تعذر حفظ الملاحظة.'));
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _closeTicket() async {
    bool confirmed = false;
    await LexiAlert.confirm(
      context,
      title: 'إغلاق التذكرة',
      text: 'هل أنت متأكد من إغلاق هذه التذكرة؟',
      confirmText: 'إغلاق',
      cancelText: 'إلغاء',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed) return;

    try {
      await ref
          .read(supportApiProvider)
          .adminUpdateTicket(ticketId: widget.ticketId, status: 'closed');
      if (!mounted) return;
      await LexiAlert.success(context, text: 'تم إغلاق التذكرة.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(
        context,
        text: _safeError(e, 'تعذر إغلاق التذكرة.'),
      );
    }
  }

  String _safeError(Object e, String fallback) {
    if (e is AppFailure) return e.message;
    return fallback;
  }

  List<SupportAttachment> _attachmentsForMessage(int messageId) {
    return _attachments.where((a) => a.messageId == messageId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'ticket_refresh',
        onPressed: _loading ? null : _load,
        child: const Icon(Icons.refresh),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ticket == null
          ? const Center(child: Text('تعذر تحميل بيانات التذكرة.'))
          : ListView(
              padding: const EdgeInsets.all(LexiSpacing.md),
              children: [
                _ticketHeader(ticket),
                const SizedBox(height: 10),
                _controlsCard(),
                const SizedBox(height: 10),
                _replyCard(),
                const SizedBox(height: 10),
                _internalNotesCard(),
                const SizedBox(height: 10),
                const Text(
                  'المحادثة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._messages.map((m) {
                  final files = _attachmentsForMessage(m.id);
                  return _adminMessageItem(m, files);
                }),
              ],
            ),
    );
  }

  Widget _ticketHeader(SupportTicket ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket.subject,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('${ticket.name} • ${ticket.phone}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(ticket.statusLabelAr),
                _chip(ticket.priorityLabelAr),
                _chip(ticket.categoryLabelAr),
                if (ticket.firstResponseOverdue || ticket.resolutionOverdue)
                  _chip('تنبيه SLA', color: Colors.red.shade100),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _closeTicket,
              icon: const Icon(Icons.lock_outline),
              label: const Text('إغلاق التذكرة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'إجراءات سريعة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _drop(
                  title: 'الحالة',
                  value: _status,
                  items: const [
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
                    ('shipping', 'الشحن'),
                    ('payment', 'الدفع'),
                    ('product', 'المنتجات'),
                    ('technical', 'تقني'),
                    ('other', 'أخرى'),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _assignController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تعيين موظف (User ID)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'وسوم (مفصولة بفاصلة)',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveChanges,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ التغييرات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _replyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرد على العميل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: null,
              hint: const Text('اختيار رد جاهز'),
              items: _cannedReplies
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(
                        e,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null || v.trim().isEmpty) return;
                _replyController.text = v;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replyController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'اكتب ردك هنا...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sending
                        ? null
                        : () => _sendReply(asNote: false),
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('إرسال رد'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sending ? null : () => _sendReply(asNote: true),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('إرسال كـ ملاحظة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _internalNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الملاحظات الداخلية',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظة داخلية غير مرئية للعميل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _savingNote ? null : _addInternalNote,
              icon: _savingNote
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.post_add_outlined),
              label: const Text('حفظ الملاحظة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminMessageItem(
    SupportMessage message,
    List<SupportAttachment> files,
  ) {
    final isInternal = message.isInternal;
    final senderLabel = switch (message.senderType) {
      'customer' => 'العميل',
      'agent' => 'الدعم',
      _ => isInternal ? 'ملاحظة داخلية' : 'النظام',
    };

    return Card(
      color: isInternal ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  senderLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(message.createdAt, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(message.message),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: files
                    .map(
                      (a) => OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(a.url);
                          if (uri == null) return;
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: Icon(
                          a.mimeType.contains('pdf')
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          size: 18,
                        ),
                        label: Text(
                          a.mimeType.contains('pdf') ? 'PDF' : 'صورة',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
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
      width: 220,
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
