import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/ui/lexi_alert.dart';

import '../controllers/admin_notification_controller.dart';

class AdminNotificationSenderPage extends ConsumerStatefulWidget {
  const AdminNotificationSenderPage({super.key});

  @override
  ConsumerState<AdminNotificationSenderPage> createState() =>
      _AdminNotificationSenderPageState();
}

class _AdminNotificationSenderPageState
    extends ConsumerState<AdminNotificationSenderPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _deepLinkController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _userIdController = TextEditingController();
  final _deviceIdController = TextEditingController();

  final _fcmProjectIdController = TextEditingController();
  final _fcmServiceAccountPathController = TextEditingController();
  final _defaultImageController = TextEditingController();
  final _ttlController = TextEditingController(text: '3600');

  String _target = 'broadcast';
  String _audience = 'customer';
  String _type = 'offer';
  String _defaultOpenMode = 'in_app';
  String _campaignOpenMode = 'in_app';
  bool _sendPush = true;
  bool _pushEnabled = false;
  bool _settingsHydrated = false;
  bool _isFetchingJson = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _deepLinkController.dispose();
    _imageUrlController.dispose();
    _userIdController.dispose();
    _deviceIdController.dispose();
    _fcmProjectIdController.dispose();
    _fcmServiceAccountPathController.dispose();
    _defaultImageController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotificationControllerProvider);

    ref.listen(adminNotificationControllerProvider, (prev, next) {
      final previousError = prev?.error;
      if (next.error != null && next.error != previousError && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    _hydrateSettings(state.firebaseSettings);

    return Scaffold(
      body: state.isLoading && state.firebaseSettings == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(adminNotificationControllerProvider.notifier)
                  .loadInitial(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFirebaseSettingsCard(state),
                  const SizedBox(height: 16),
                  _buildComposeCard(state),
                  if (state.lastCampaignResult != null) ...[
                    const SizedBox(height: 16),
                    _buildLastResultCard(state.lastCampaignResult!),
                  ],
                  const SizedBox(height: 16),
                  _buildCampaignsHistory(state.campaigns),
                ],
              ),
            ),
    );
  }

  void _hydrateSettings(Map<String, dynamic>? settings) {
    if (_settingsHydrated || settings == null) {
      return;
    }

    _settingsHydrated = true;
    _pushEnabled = (settings['enabled'] == 1 || settings['enabled'] == true);
    _defaultImageController.text = (settings['default_image_url'] ?? '')
        .toString();
    _ttlController.text = (settings['ttl_seconds'] ?? 3600).toString();
    _defaultOpenMode = (settings['default_open_mode'] ?? 'in_app').toString();
    _campaignOpenMode = _defaultOpenMode;
    _fcmProjectIdController.text = (settings['fcm_project_id'] ?? '')
        .toString();
    _fcmServiceAccountPathController.text =
        (settings['fcm_service_account_path_masked'] ?? '').toString();
  }

  Widget _buildFirebaseSettingsCard(AdminNotificationUiState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إعدادات Firebase',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل الإرسال عبر FCM'),
              subtitle: const Text(
                'عند الإيقاف سيتم حفظ الإشعار داخل التطبيق فقط',
              ),
              value: _pushEnabled,
              onChanged: (value) => setState(() => _pushEnabled = value),
            ),
            TextField(
              controller: _fcmProjectIdController,
              decoration: const InputDecoration(
                labelText: 'FCM Project ID',
                hintText: 'مثال: leximegastore-25c4d',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fcmServiceAccountPathController,
              decoration: InputDecoration(
                labelText: 'FCM Service Account JSON Path',
                hintText: 'المسار البرمجي لملف مفاتيح Firebase',
                suffixIcon: IconButton(
                  icon: _isFetchingJson
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  tooltip: 'جلب وتعبئة تلقائية من الرابط',
                  onPressed: _isFetchingJson ? null : _fetchAndAutoFillFCM,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _defaultImageController,
              decoration: const InputDecoration(
                labelText: 'رابط صورة افتراضية (اختياري)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _defaultOpenMode,
                    decoration: const InputDecoration(
                      labelText: 'وضع الفتح الافتراضي',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'in_app',
                        child: Text('داخل التطبيق'),
                      ),
                      DropdownMenuItem(
                        value: 'external',
                        child: Text('رابط خارجي'),
                      ),
                      DropdownMenuItem(
                        value: 'product',
                        child: Text('صفحة منتج'),
                      ),
                      DropdownMenuItem(
                        value: 'category',
                        child: Text('صفحة قسم'),
                      ),
                      DropdownMenuItem(
                        value: 'deals',
                        child: Text('صفحة العروض'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _defaultOpenMode = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ttlController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة حياة الإشعار (ثانية)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: state.isSavingSettings ? null : _saveFirebaseSettings,
              icon: state.isSavingSettings
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                state.isSavingSettings
                    ? 'جارٍ الحفظ...'
                    : 'حفظ إعدادات Firebase',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeCard(AdminNotificationUiState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إرسال إشعار / عرض',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _target,
                decoration: const InputDecoration(labelText: 'الاستهداف'),
                items: const [
                  DropdownMenuItem(
                    value: 'broadcast',
                    child: Text('كل العملاء'),
                  ),
                  DropdownMenuItem(
                    value: 'all_admins',
                    child: Text('كل المدراء'),
                  ),
                  DropdownMenuItem(
                    value: 'specific_user',
                    child: Text('مستخدم محدد (User ID)'),
                  ),
                  DropdownMenuItem(
                    value: 'specific_device',
                    child: Text('جهاز محدد (Device ID)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _target = value;
                      if (_target == 'all_admins') {
                        _audience = 'admin';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'الجمهور'),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('عملاء')),
                  DropdownMenuItem(value: 'admin', child: Text('إدارة')),
                ],
                onChanged: _target == 'all_admins'
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _audience = value);
                        }
                      },
              ),
              if (_target == 'specific_user') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _userIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'User ID'),
                  validator: (value) {
                    if (_target != 'specific_user') return null;
                    final id = int.tryParse((value ?? '').trim());
                    if (id == null || id <= 0) {
                      return 'أدخل User ID صالح';
                    }
                    return null;
                  },
                ),
              ],
              if (_target == 'specific_device') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _deviceIdController,
                  decoration: const InputDecoration(labelText: 'Device ID'),
                  validator: (value) {
                    if (_target != 'specific_device') return null;
                    if ((value ?? '').trim().isEmpty) {
                      return 'أدخل Device ID';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'نوع الرسالة'),
                items: const [
                  DropdownMenuItem(value: 'offer', child: Text('عرض')),
                  DropdownMenuItem(value: 'manual', child: Text('تنبيه يدوي')),
                  DropdownMenuItem(value: 'announcement', child: Text('إعلان')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'العنوان'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'العنوان مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bodyController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'نص الإشعار'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'نص الإشعار مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _campaignOpenMode,
                decoration: const InputDecoration(labelText: 'طريقة الفتح'),
                items: const [
                  DropdownMenuItem(
                    value: 'in_app',
                    child: Text('داخل التطبيق'),
                  ),
                  DropdownMenuItem(
                    value: 'external',
                    child: Text('رابط خارجي'),
                  ),
                  DropdownMenuItem(
                    value: 'product',
                    child: Text('منتج (ضع ID)'),
                  ),
                  DropdownMenuItem(
                    value: 'category',
                    child: Text('قسم (ضع ID)'),
                  ),
                  DropdownMenuItem(value: 'deals', child: Text('العروض')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _campaignOpenMode = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _deepLinkController,
                decoration: InputDecoration(
                  labelText:
                      _campaignOpenMode == 'product' ||
                          _campaignOpenMode == 'category'
                      ? 'المعرّف (ID)'
                      : 'الرابط الداخلي/الخارجي',
                  hintText: _campaignOpenMode == 'product'
                      ? 'مثال: 123'
                      : _campaignOpenMode == 'category'
                      ? 'مثال: 33'
                      : 'مثال: /deals أو https://...',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'رابط الصورة التي ستظهر في الإشعار (اختياري)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('إرسال Push عبر Firebase'),
                value: _sendPush,
                onChanged: (value) => setState(() => _sendPush = value),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: state.isLoading ? null : _submitCampaign,
                icon: state.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(state.isLoading ? 'جارٍ الإرسال...' : 'إرسال الآن'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastResultCard(Map<String, dynamic> campaign) {
    final targeted = (campaign['targeted_count'] ?? 0).toString();
    final success = (campaign['push_success'] ?? 0).toString();
    final failed = (campaign['push_failed'] ?? 0).toString();
    final stored = (campaign['stored_count'] ?? 0).toString();
    final status = (campaign['provider_status'] ?? '').toString();

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آخر نتيجة إرسال',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('تم الحفظ داخل صندوق الإشعارات: $stored'),
            Text('الأجهزة المستهدفة (Push): $targeted'),
            Text('نجح الإرسال: $success'),
            Text('فشل الإرسال: $failed'),
            Text('حالة المزوّد: $status'),
            if ((campaign['provider_error'] ?? '').toString().trim().isNotEmpty)
              Text(
                'تفاصيل: ${campaign['provider_error']}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsHistory(List<Map<String, dynamic>> campaigns) {
    if (campaigns.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا يوجد سجل حملات حتى الآن.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سجل آخر الحملات',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ...campaigns.take(10).map((item) {
              final title = (item['title_ar'] ?? '').toString();
              final date = (item['created_at'] ?? '').toString();
              final targeted = (item['targeted_count'] ?? 0).toString();
              final success = (item['push_success'] ?? 0).toString();
              final failed = (item['push_failed'] ?? 0).toString();
              final status = (item['provider_status'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('الوقت: $date'),
                    Text('المستهدف: $targeted | نجح: $success | فشل: $failed'),
                    Text('الحالة: $status'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAndAutoFillFCM() async {
    final url = _fcmServiceAccountPathController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      LexiAlert.warning(
        context,
        text: 'يرجى إدخال رابط (URL) صالح للملف أولاً.',
      );
      return;
    }

    setState(() => _isFetchingJson = true);
    try {
      final response = await Dio().get(url);
      final data = response.data;

      Map<String, dynamic>? jsonMap;
      if (data is Map<String, dynamic>) {
        jsonMap = data;
      } else if (data is String) {
        jsonMap = jsonDecode(data) as Map<String, dynamic>;
      }

      if (jsonMap != null && jsonMap.containsKey('project_id')) {
        final projectId = jsonMap['project_id'].toString();
        _fcmProjectIdController.text = projectId;
        if (mounted) {
          LexiAlert.success(
            context,
            text: 'تم جلب معرف المشروع بنجاح: $projectId',
          );
        }
      } else {
        if (mounted) {
          LexiAlert.error(context, text: 'الملف لا يحتوي على project_id صالح.');
        }
      }
    } catch (e) {
      if (mounted) {
        LexiAlert.error(
          context,
          text:
              'فشل جلب الملف. تأكد من صحة الرابط ومن سياسة الـ CORS إن كنت تستخدم الويب.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingJson = false);
      }
    }
  }

  Future<void> _saveFirebaseSettings() async {
    final ttl = int.tryParse(_ttlController.text.trim()) ?? 3600;

    await ref
        .read(adminNotificationControllerProvider.notifier)
        .saveFirebaseSettings(
          enabled: _pushEnabled,
          fcmProjectId: _fcmProjectIdController.text,
          fcmServiceAccountPath: _fcmServiceAccountPathController.text,
          defaultImageUrl: _defaultImageController.text,
          defaultOpenMode: _defaultOpenMode,
          ttlSeconds: ttl,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات Firebase بنجاح')),
    );
  }

  Future<void> _submitCampaign() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if ((_campaignOpenMode == 'product' || _campaignOpenMode == 'category') &&
        int.tryParse(_deepLinkController.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عند اختيار منتج/قسم يجب إدخال رقم ID صحيح'),
        ),
      );
      return;
    }

    await ref
        .read(adminNotificationControllerProvider.notifier)
        .sendNotification(
          target: _target,
          audience: _audience,
          titleAr: _titleController.text,
          bodyAr: _bodyController.text,
          type: _type,
          openMode: _campaignOpenMode,
          sendPush: _sendPush,
          deepLink: _deepLinkController.text,
          imageUrl: _imageUrlController.text,
          userId: int.tryParse(_userIdController.text.trim()),
          deviceId: _deviceIdController.text,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال الإشعار وتسجيل الحملة')),
    );
  }
}
