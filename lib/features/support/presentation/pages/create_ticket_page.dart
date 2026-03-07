import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../controllers/support_controller.dart';

class CreateTicketPage extends ConsumerStatefulWidget {
  const CreateTicketPage({super.key});

  @override
  ConsumerState<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends ConsumerState<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedPriority = 'medium';
  String _selectedCategory = 'other';
  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': 'استفسار عام'},
    {'value': 'technical', 'label': 'مشكلة تقنية'},
    {'value': 'billing', 'label': 'الفواتير والمدفوعات'},
    {'value': 'orders', 'label': 'الطلبات والشحن'},
    {'value': 'other', 'label': 'أخرى'},
  ];

  final List<Map<String, String>> _priorities = [
    {'value': 'low', 'label': 'منخفضة'},
    {'value': 'medium', 'label': 'متوسطة'},
    {'value': 'high', 'label': 'عالية'},
    {'value': 'urgent', 'label': 'عاجلة'},
  ];

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(supportRepositoryProvider);
      final result = await repository.createTicket({
        'name': 'User', // Placeholder, backend uses current user
        'subject': _subjectController.text,
        'message': _messageController.text,
        'priority': _selectedPriority,
        'category': _selectedCategory,
      });

      if (!mounted) return;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red,
            ),
          );
        },
        (ticket) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء التذكرة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(supportControllerProvider);
          context.pushReplacement(
            '/support/tickets/${ticket.id}/chat?token=${Uri.encodeComponent(ticket.chatToken)}',
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء تذكرة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _subjectController,
                label: 'عنوان المشكلة',
                hint: 'لخص المشكلة في بضع كلمات',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال عنوان المشكلة';
                  }
                  if (value.length < 3) {
                    return 'العنوان قصير جداً';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category['value'],
                    child: Text(category['label']!),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'الأولوية',
                  border: OutlineInputBorder(),
                ),
                items: _priorities.map((priority) {
                  return DropdownMenuItem(
                    value: priority['value'],
                    child: Text(priority['label']!),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedPriority = value!),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _messageController,
                label: 'تفاصيل المشكلة',
                hint: 'اشرح المشكلة بالتفصيل...',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال تفاصيل المشكلة';
                  }
                  if (value.length < 10) {
                    return 'يرجى كتابة وصف أكثر تفصيلاً (10 أحرف على الأقل)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'إنشاء التذكرة',
                onPressed: _isLoading ? null : _submitTicket,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
