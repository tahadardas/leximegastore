import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../ui/forms/focus_chain.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../data/local/support_ticket_store.dart';
import '../../data/support_api.dart';

Future<void> showCreateSupportTicketSheet({
  required BuildContext context,
  required WidgetRef ref,
  String initialName = '',
  String initialPhone = '',
  String initialEmail = '',
}) async {
  final nameController = TextEditingController(text: initialName);
  final phoneController = TextEditingController(text: initialPhone);
  final emailController = TextEditingController(text: initialEmail);
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  final nameFocus = FocusNode();
  final phoneFocus = FocusNode();
  final emailFocus = FocusNode();
  final subjectFocus = FocusNode();
  final messageFocus = FocusNode();
  final focusChain = FocusChain([
    nameFocus,
    phoneFocus,
    emailFocus,
    subjectFocus,
    messageFocus,
  ]);

  final formKey = GlobalKey<FormState>();
  String category = 'other';
  String priority = 'medium';
  bool isLoading = false;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    focusChain.enableAutoScroll();
  });

  final categories = const [
    ('shipping', 'الشحن'),
    ('payment', 'الدفع'),
    ('product', 'المنتجات'),
    ('technical', 'مشكلة تقنية'),
    ('other', 'أخرى'),
  ];

  final priorities = const [
    ('low', 'منخفضة'),
    ('medium', 'متوسطة'),
    ('high', 'عالية'),
    ('urgent', 'عاجلة'),
  ];

  Future<void> submit(StateSetter setSheetState) async {
    if (!(formKey.currentState?.validate() ?? false) || isLoading) {
      return;
    }

    setSheetState(() => isLoading = true);
    try {
      final api = ref.read(supportApiProvider);
      final store = ref.read(supportTicketStoreProvider);

      final data = await api.createTicket(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        subject: subjectController.text.trim(),
        message: messageController.text.trim(),
        category: category,
        priority: priority,
      );

      int toInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? 0;
        return 0;
      }

      final ticketId = toInt(data['ticket_id']);
      final ticketNumber = (data['ticket_number'] ?? '').toString();
      final token = (data['chat_token'] ?? '').toString();
      final status = (data['status'] ?? 'open').toString();
      final statusLabelAr = (data['status_label_ar'] ?? 'مفتوحة').toString();

      if (ticketId <= 0 || token.trim().isEmpty) {
        throw AppFailure('تعذر إنشاء التذكرة حالياً.');
      }

      await store.saveFromCreateResponse(
        ticketId: ticketId,
        ticketNumber: ticketNumber,
        chatToken: token,
        subject: subjectController.text.trim(),
        status: status,
        statusLabelAr: statusLabelAr,
        phone: phoneController.text.trim(),
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (!context.mounted) return;
      await LexiAlert.success(context, text: 'تم إنشاء التذكرة بنجاح');

      if (!context.mounted) return;
      context.push(
        '/support/tickets/$ticketId/chat?token=${Uri.encodeComponent(token)}',
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e is AppFailure
          ? e.message
          : 'تعذر إنشاء التذكرة حالياً.';
      await LexiAlert.error(context, text: message);
    } finally {
      if (context.mounted) {
        setSheetState(() => isLoading = false);
      }
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final viewInsetsBottom = MediaQuery.of(sheetContext).viewInsets.bottom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsetsBottom),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return LexiSafeBottom(
                keyboardAware: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('تواصل مع الدعم', style: LexiTypography.h3),
                          const SizedBox(height: LexiSpacing.md),
                          TextFormField(
                            controller: nameController,
                            focusNode: nameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                focusChain.focusNext(context, nameFocus),
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'الاسم',
                            ),
                            validator: (v) => (v ?? '').trim().length < 2
                                ? 'يرجى إدخال الاسم بشكل صحيح'
                                : null,
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          TextFormField(
                            controller: phoneController,
                            focusNode: phoneFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                focusChain.focusNext(context, phoneFocus),
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v ?? '').trim().length < 9
                                ? 'يرجى إدخال رقم هاتف صحيح'
                                : null,
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          TextFormField(
                            controller: emailController,
                            focusNode: emailFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                focusChain.focusNext(context, emailFocus),
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني (اختياري)',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          TextFormField(
                            controller: subjectController,
                            focusNode: subjectFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                focusChain.focusNext(context, subjectFocus),
                            decoration: const InputDecoration(
                              labelText: 'عنوان المشكلة',
                            ),
                            validator: (v) => (v ?? '').trim().length < 3
                                ? 'عنوان المشكلة مطلوب'
                                : null,
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          TextFormField(
                            controller: messageController,
                            focusNode: messageFocus,
                            textInputAction: TextInputAction.done,
                            minLines: 4,
                            maxLines: 6,
                            onFieldSubmitted: (_) => focusChain.focusDone(
                              context,
                              () => submit(setSheetState),
                            ),
                            decoration: const InputDecoration(
                              labelText: 'تفاصيل المشكلة',
                              hintText: 'اكتب تفاصيل واضحة للمشكلة...',
                              alignLabelWithHint: true,
                            ),
                            validator: (v) => (v ?? '').trim().length < 10
                                ? 'يرجى كتابة تفاصيل المشكلة (10 أحرف على الأقل).'
                                : null,
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: const InputDecoration(
                              labelText: 'نوع المشكلة',
                            ),
                            items: categories
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e.$1,
                                    child: Text(e.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: isLoading
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setSheetState(() => category = v);
                                  },
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'الأولوية',
                            ),
                            items: priorities
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e.$1,
                                    child: Text(e.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: isLoading
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setSheetState(() => priority = v);
                                  },
                          ),
                          const SizedBox(height: LexiSpacing.md),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () => submit(setSheetState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LexiColors.brandPrimary,
                              foregroundColor: LexiColors.brandBlack,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('إنشاء تذكرة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  nameController.dispose();
  phoneController.dispose();
  emailController.dispose();
  subjectController.dispose();
  messageController.dispose();
  focusChain.dispose();
}
