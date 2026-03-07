import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/polling_manager.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../data/local/support_ticket_store.dart';
import '../../data/support_api.dart';
import '../../domain/entities/support_attachment.dart';
import '../../domain/entities/support_message.dart';
import '../../domain/entities/support_ticket.dart';

class SupportTicketChatPage extends ConsumerStatefulWidget {
  final int ticketId;
  final String token;

  const SupportTicketChatPage({
    super.key,
    required this.ticketId,
    required this.token,
  });

  @override
  ConsumerState<SupportTicketChatPage> createState() =>
      _SupportTicketChatPageState();
}

class _SupportTicketChatPageState extends ConsumerState<SupportTicketChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  bool _closing = false;
  bool _showRatingBox = false;

  int _rating = 5;
  int _lastMessageId = 0;
  String _resolvedToken = '';

  SupportTicket? _ticket;
  List<SupportMessage> _messages = const [];
  List<SupportAttachment> _attachments = const [];

  @override
  void initState() {
    super.initState();
    _resolvedToken = widget.token.trim();
    _loadDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(pollingManagerProvider).registerScreenPoller(
        key: _pollerKey,
        interval: const Duration(seconds: 6),
        task: _poll,
        runImmediately: false,
      );
    });
  }

  @override
  void dispose() {
    ref.read(pollingManagerProvider).unregisterScreenPoller(_pollerKey);
    _messageController.dispose();
    _feedbackController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _pollerKey => 'support-ticket:${widget.ticketId}';

  Future<void> _loadDetails({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final api = ref.read(supportApiProvider);
      final store = ref.read(supportTicketStoreProvider);
      final token = await _resolveTicketToken();
      if (token.isEmpty) {
        throw AppFailure(
          'تعذر الوصول إلى التذكرة. يرجى تسجيل الدخول ثم إعادة المحاولة.',
        );
      }
      final result = await api.getTicketDetails(
        ticketId: widget.ticketId,
        token: token,
      );

      int maxId = 0;
      for (final m in result.messages) {
        if (m.id > maxId) maxId = m.id;
      }

      await store.updateTicketStatus(
        ticketId: widget.ticketId,
        status: result.ticket.status,
        statusLabelAr: result.ticket.statusLabelAr,
      );

      if (!mounted) return;
      setState(() {
        _ticket = result.ticket;
        _messages = result.messages;
        _attachments = result.attachments;
        _lastMessageId = maxId;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final message = _safeError(e, 'تعذر تحميل التذكرة.');
      await LexiAlert.error(context, text: message);
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _poll() async {
    final ticket = _ticket;
    if (!mounted || ticket == null) return;

    try {
      final api = ref.read(supportApiProvider);
      final store = ref.read(supportTicketStoreProvider);
      final token = await _resolveTicketToken();
      if (token.isEmpty) return;
      final result = await api.poll(
        ticketId: widget.ticketId,
        token: token,
        sinceId: _lastMessageId,
      );

      if (!mounted) return;

      if (result.messages.isNotEmpty || result.attachments.isNotEmpty) {
        final newMessages = [..._messages, ...result.messages];
        final newAttachments = [..._attachments, ...result.attachments];

        bool hasAgentReply = false;
        for (final m in result.messages) {
          if (m.senderType == 'agent') {
            hasAgentReply = true;
            break;
          }
        }

        setState(() {
          _messages = newMessages;
          _attachments = newAttachments;
          _lastMessageId = result.lastMessageId > _lastMessageId
              ? result.lastMessageId
              : _lastMessageId;
          _ticket = _ticket?.copyWith(
            status: result.status,
            statusLabelAr: result.statusLabelAr,
            updatedAt: DateTime.now().toIso8601String(),
            lastMessageAt: DateTime.now().toIso8601String(),
          );
        });

        await store.updateTicketStatus(
          ticketId: widget.ticketId,
          status: result.status,
          statusLabelAr: result.statusLabelAr,
        );

        if (!mounted) return;
        if (hasAgentReply) {
          ScaffoldMessenger.of(context).showSnackBar(
            lexiFloatingSnackBar(
              context,
              content: const Text('رد جديد من الدعم'),
            ),
          );
        }

        _scrollToBottom();
      } else {
        await store.updateTicketStatus(
          ticketId: widget.ticketId,
          status: result.status,
          statusLabelAr: result.statusLabelAr,
        );
        if (!mounted) return;
        setState(() {
          _ticket = _ticket?.copyWith(
            status: result.status,
            statusLabelAr: result.statusLabelAr,
            updatedAt: DateTime.now().toIso8601String(),
          );
        });
      }
    } catch (_) {
      // Silent polling failure.
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final api = ref.read(supportApiProvider);
      final token = await _resolveTicketToken();
      if (token.isEmpty) {
        throw AppFailure('تعذر الوصول إلى التذكرة.');
      }
      final sent = await api.sendMessage(
        ticketId: widget.ticketId,
        token: token,
        message: text,
      );

      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _messages = [..._messages, sent];
        _lastMessageId = sent.id > _lastMessageId ? sent.id : _lastMessageId;
        _ticket = _ticket?.copyWith(
          status: 'pending_admin',
          statusLabelAr: 'بانتظار الدعم',
          updatedAt: DateTime.now().toIso8601String(),
          lastMessageAt: DateTime.now().toIso8601String(),
        );
      });

      await ref
          .read(supportTicketStoreProvider)
          .updateTicketStatus(
            ticketId: widget.ticketId,
            status: 'pending_admin',
            statusLabelAr: 'بانتظار الدعم',
          );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(
        context,
        text: _safeError(e, 'تعذر إرسال الرسالة.'),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    if (_uploading) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final token = await _resolveTicketToken();
      if (token.isEmpty) {
        throw AppFailure('تعذر الوصول إلى التذكرة.');
      }
      final bytes = await file.readAsBytes();
      String mimeType = 'image/jpeg';
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lower.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (lower.endsWith('.gif')) {
        mimeType = 'image/gif';
      }

      await ref
          .read(supportApiProvider)
          .uploadAttachment(
            ticketId: widget.ticketId,
            token: token,
            bytes: bytes,
            fileName: file.name,
            mimeType: mimeType,
          );

      if (!mounted) return;
      await _loadDetails(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('تم رفع المرفق بنجاح.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(context, text: _safeError(e, 'تعذر رفع المرفق.'));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _submitRatingAndClose() async {
    if (_closing) return;

    setState(() => _closing = true);
    try {
      final api = ref.read(supportApiProvider);
      final token = await _resolveTicketToken();
      if (token.isEmpty) {
        throw AppFailure('تعذر الوصول إلى التذكرة.');
      }
      await api.closeTicket(
        ticketId: widget.ticketId,
        token: token,
        rating: _rating,
        feedback: _feedbackController.text.trim(),
      );

      if (!mounted) return;
      await ref
          .read(supportTicketStoreProvider)
          .updateTicketStatus(
            ticketId: widget.ticketId,
            status: 'closed',
            statusLabelAr: 'مغلقة',
          );
      await _loadDetails(silent: true);

      if (!mounted) return;
      await LexiAlert.success(context, text: 'تم إغلاق التذكرة وحفظ التقييم.');
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(
        context,
        text: _safeError(e, 'تعذر إرسال التقييم حالياً.'),
      );
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Ignore scroll errors
      }
    });
  }

  List<SupportAttachment> _attachmentsForMessage(int messageId) {
    return _attachments.where((e) => e.messageId == messageId).toList();
  }

  String _safeError(Object e, String fallback) {
    if (e is AppFailure) return e.message;
    return fallback;
  }

  Future<String> _resolveTicketToken() async {
    final directToken = _resolvedToken.trim();
    if (directToken.isNotEmpty) {
      return directToken;
    }

    final store = ref.read(supportTicketStoreProvider);
    final cached = await store.getById(widget.ticketId);
    final cachedToken = cached?.chatToken.trim() ?? '';
    if (cachedToken.isNotEmpty) {
      _resolvedToken = cachedToken;
      return cachedToken;
    }

    try {
      final now = DateTime.now().toIso8601String();
      final tickets = await ref.read(supportApiProvider).getMyTickets();
      String matchedToken = '';

      for (final ticket in tickets) {
        final updatedAt = ticket.updatedAt.trim().isNotEmpty
            ? ticket.updatedAt.trim()
            : now;
        final createdAt = ticket.createdAt.trim().isNotEmpty
            ? ticket.createdAt.trim()
            : updatedAt;

        await store.save(
          LocalSupportTicket(
            ticketId: ticket.id,
            ticketNumber: ticket.ticketNumber,
            chatToken: ticket.chatToken,
            subject: ticket.subject,
            status: ticket.status,
            statusLabelAr: ticket.statusLabelAr,
            phone: ticket.phone,
            updatedAt: updatedAt,
            createdAt: createdAt,
          ),
        );

        if (ticket.id == widget.ticketId &&
            ticket.chatToken.trim().isNotEmpty) {
          matchedToken = ticket.chatToken.trim();
        }
      }

      if (matchedToken.isNotEmpty) {
        _resolvedToken = matchedToken;
        return matchedToken;
      }
    } catch (_) {
      // Best effort only; caller handles empty token.
    }

    return '';
  }

  bool get _isClosed {
    final status = (_ticket?.status ?? '').trim();
    return status == 'closed';
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;

    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: LexiAppBar(
        title: ticket?.ticketNumber.isNotEmpty == true
            ? ticket!.ticketNumber
            : 'تذكرة الدعم',
        actions: [
          IconButton(
            onPressed: () {
              ShareService.instance.shareTicketById(ticketId: widget.ticketId);
            },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: _loading ? null : () => _loadDetails(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ticket == null
          ? const Center(child: Text('تعذر تحميل بيانات التذكرة.'))
          : Column(
              children: [
                _StatusBanner(statusLabelAr: ticket.statusLabelAr),
                if (!_isClosed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => _showRatingBox = !_showRatingBox);
                        },
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('إغلاق التذكرة وتقييم الدعم'),
                      ),
                    ),
                  ),
                if (_isClosed || _showRatingBox)
                  _RatingCard(
                    rating: _rating,
                    feedbackController: _feedbackController,
                    loading: _closing,
                    onRatingChanged: (v) => setState(() => _rating = v),
                    onSubmit: _submitRatingAndClose,
                    closed: _isClosed,
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final mine = m.senderType == 'customer';
                      final system = m.senderType == 'system';
                      final files = _attachmentsForMessage(m.id);
                      return _MessageBubble(
                        message: m,
                        attachments: files,
                        mine: mine,
                        system: system,
                      );
                    },
                  ),
                ),
                if (!_isClosed)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        8,
                        8,
                        8,
                        10,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _uploading
                                ? null
                                : _pickAndUploadAttachment,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.attach_file),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'اكتب رسالتك...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sending ? null : _sendMessage,
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String statusLabelAr;

  const _StatusBanner({required this.statusLabelAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LexiColors.brandPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'الحالة: $statusLabelAr',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final List<SupportAttachment> attachments;
  final bool mine;
  final bool system;

  const _MessageBubble({
    required this.message,
    required this.attachments,
    required this.mine,
    required this.system,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = system
        ? LexiColors.neutral200
        : (mine
              ? LexiColors.brandPrimary.withValues(alpha: 0.22)
              : Colors.white);
    final align = system
        ? Alignment.center
        : (mine ? Alignment.centerRight : Alignment.centerLeft);

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LexiColors.neutral300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.message),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...attachments.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: OutlinedButton.icon(
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
                      a.mimeType.contains('pdf') ? 'ملف PDF' : 'صورة مرفقة',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              message.createdAt,
              style: const TextStyle(
                fontSize: 11,
                color: LexiColors.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final int rating;
  final TextEditingController feedbackController;
  final bool loading;
  final bool closed;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  const _RatingCard({
    required this.rating,
    required this.feedbackController,
    required this.loading,
    required this.closed,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LexiColors.neutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            closed ? 'قيّم تجربة الدعم' : 'إغلاق التذكرة مع التقييم',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                onPressed: loading ? null : () => onRatingChanged(value),
                icon: Icon(
                  value <= rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          TextField(
            controller: feedbackController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'أضف ملاحظتك (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(closed ? 'حفظ التقييم' : 'إغلاق التذكرة'),
          ),
        ],
      ),
    );
  }
}
