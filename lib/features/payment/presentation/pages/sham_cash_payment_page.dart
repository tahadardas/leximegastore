import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../config/constants/endpoints.dart';
import '../../../../core/locks/submit_locks.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../orders/data/local/pending_shamcash_store.dart';
import '../../../orders/data/realtime/orders_realtime_service.dart';

class ShamCashPaymentPage extends ConsumerStatefulWidget {
  final String orderId;
  final double amount;
  final String currency;
  final String? phone;
  final String? accountName;
  final String? qrValue;
  final String? barcodeValue;
  final String? instructionsAr;
  final String? uploadEndpoint;

  const ShamCashPaymentPage({
    super.key,
    required this.orderId,
    required this.amount,
    required this.currency,
    this.phone,
    this.accountName,
    this.qrValue,
    this.barcodeValue,
    this.instructionsAr,
    this.uploadEndpoint,
  });

  @override
  ConsumerState<ShamCashPaymentPage> createState() =>
      _ShamCashPaymentPageState();
}

class _ShamCashPaymentPageState extends ConsumerState<ShamCashPaymentPage> {
  static final Set<String> _shownPendingReminderOrderIds = <String>{};

  final _picker = ImagePicker();

  XFile? _proofImage;
  Uint8List? _proofBytes;
  bool _isUploading = false;
  bool _isLoadingConfig = false;
  String? _configError;

  late String _accountName;
  late String _qrValue;
  late String _barcodeValue;
  late String _instructionsAr;

  @override
  void initState() {
    super.initState();
    _accountName = widget.accountName?.trim().isNotEmpty == true
        ? widget.accountName!.trim()
        : 'متجر ليكسي ميجا';
    _qrValue = widget.qrValue?.trim().isNotEmpty == true
        ? widget.qrValue!.trim()
        : '';
    _barcodeValue = widget.barcodeValue?.trim().isNotEmpty == true
        ? widget.barcodeValue!.trim()
        : '';
    _instructionsAr = widget.instructionsAr?.trim().isNotEmpty == true
        ? widget.instructionsAr!.trim()
        : 'اكتب رقم الطلب في ملاحظات التحويل ثم ارفع صورة الإيصال.';

    _loadConfig();
    _schedulePendingProofReminder();
  }

  void _schedulePendingProofReminder() {
    final normalizedOrderId = widget.orderId.trim();
    if (normalizedOrderId.isEmpty) {
      return;
    }
    if (_shownPendingReminderOrderIds.contains(normalizedOrderId)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _proofImage != null) {
        return;
      }
      _shownPendingReminderOrderIds.add(normalizedOrderId);
      unawaited(
        LexiAlert.info(
          context,
          title: 'تنبيه',
          text:
              'إذا لم ترفع إثبات الدفع الآن، فطلبك محفوظ في القائمة الجانبية ضمن صفحة "شام كاش غير المكتملة".',
        ),
      );
    });
  }

  Future<void> _loadConfig() async {
    if (_qrValue.isNotEmpty && _barcodeValue.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingConfig = true;
      _configError = null;
    });

    try {
      final client = ref.read(dioClientProvider);
      final response = await client.get(
        Endpoints.shamCashConfig(),
        options: Options(extra: const {'requiresAuth': false}),
      );
      final rawMap = extractMap(response.data);
      final map = extractMap(
        rawMap['shamcash'] ?? rawMap,
      ); // fallback to rawMap for older API

      setState(() {
        _accountName =
            (map['account_name'] ?? _accountName).toString().trim().isEmpty
            ? _accountName
            : map['account_name'].toString().trim();
        _qrValue = (map['qr_value'] ?? _qrValue).toString().trim();
        _barcodeValue = (map['barcode_value'] ?? _barcodeValue)
            .toString()
            .trim();
        _instructionsAr = (map['instructions_ar'] ?? _instructionsAr)
            .toString()
            .trim();
      });
    } catch (e) {
      setState(() {
        _configError = 'تعذر تحميل إعدادات شام كاش حالياً.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    setState(() {
      _proofImage = image;
      _proofBytes = bytes;
    });
  }

  Future<void> _uploadProof() async {
    if (_proofImage == null) {
      return;
    }

    final phone = widget.phone?.trim() ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('رقم الهاتف مطلوب قبل رفع إثبات الدفع.'),
          backgroundColor: LexiColors.error,
        ),
      );
      return;
    }

    var lockAcquired = false;
    await ref
        .read(submitLocksProvider)
        .runShamCashProofUpload<void>(
          orderId: widget.orderId,
          action: () async {
            lockAcquired = true;
            setState(() => _isUploading = true);

            try {
              final client = ref.read(dioClientProvider);
              final proofBytes =
                  _proofBytes ?? await _proofImage!.readAsBytes();
              final multipart = MultipartFile.fromBytes(
                proofBytes,
                filename: _proofImage!.name,
              );
              final uploadPath =
                  widget.uploadEndpoint?.trim().isNotEmpty == true
                  ? widget.uploadEndpoint!.trim()
                  : Endpoints.shamCashProofUpload();

              await client.post(
                uploadPath,
                data: FormData.fromMap({
                  'order_id': widget.orderId,
                  'phone': phone,
                  'proof_image': multipart,
                }),
                options: Options(
                  contentType: 'multipart/form-data',
                  extra: const {'requiresAuth': false},
                ),
              );

              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                lexiFloatingSnackBar(
                  context,
                  content: const Text('تم رفع إثبات الدفع بنجاح.'),
                  backgroundColor: LexiColors.primary,
                ),
              );

              await ref
                  .read(pendingShamCashStoreProvider)
                  .remove(widget.orderId);
              await ref
                  .read(ordersRealtimeServiceProvider)
                  .notifyOrderMutation();
              if (!mounted) {
                return;
              }

              final encodedPhone = Uri.encodeComponent(phone);
              context.go(
                '/orders/pending?order_id=${widget.orderId}&phone=$encodedPhone',
              );
            } on DioException catch (e) {
              if (!mounted) {
                return;
              }

              final responseMap = extractMap(e.response?.data);
              final errorMap = extractMap(responseMap['error']);
              final errorCode = (errorMap['code'] ?? responseMap['code'] ?? '')
                  .toString()
                  .trim();
              final errorMessage =
                  (errorMap['message'] ?? responseMap['message'] ?? '')
                      .toString()
                      .trim();

              final isInvalidStatus =
                  e.response?.statusCode == 422 &&
                  errorCode == 'invalid_status';

              final userMessage = _safeApiMessage(
                errorMessage,
                fallback: isInvalidStatus
                    ? '\u062d\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628 \u0644\u0627 \u062a\u0633\u0645\u062d \u0628\u0631\u0641\u0639 \u0627\u0644\u0625\u062b\u0628\u0627\u062a \u062d\u0627\u0644\u064a\u0627\u064b. \u062d\u062f\u0651\u062b \u0648\u0623\u0639\u062f \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629.'
                    : '\u062a\u0639\u0630\u0631 \u0631\u0641\u0639 \u0625\u062b\u0628\u0627\u062a \u0627\u0644\u062f\u0641\u0639 \u062d\u0627\u0644\u064a\u0627\u064b. \u062d\u0627\u0648\u0644 \u0645\u062c\u062f\u062f\u0627\u064b.',
              );

              ScaffoldMessenger.of(context).showSnackBar(
                lexiFloatingSnackBar(
                  context,
                  content: Text(userMessage),
                  backgroundColor: LexiColors.error,
                ),
              );
            } catch (_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                lexiFloatingSnackBar(
                  context,
                  content: const Text(
                    'تعذر رفع إثبات الدفع حالياً. حاول مجدداً.',
                  ),
                  backgroundColor: LexiColors.error,
                ),
              );
            } finally {
              if (mounted) {
                setState(() => _isUploading = false);
              }
            }
          },
        );

    if (!lockAcquired && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('جاري رفع إثبات الدفع لهذا الطلب بالفعل.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _safeApiMessage(String raw, {required String fallback}) {
    final text = raw.trim();
    if (text.isEmpty) {
      return fallback;
    }

    final lower = text.toLowerCase();
    const blockedTokens = <String>[
      'http://',
      'https://',
      'wp-json',
      'rest_route',
      'dioexception',
      'socketexception',
      'xmlhttprequest',
      '<html',
      '</html',
      'stacktrace',
    ];

    if (blockedTokens.any(lower.contains)) {
      return fallback;
    }

    return text;
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      lexiFloatingSnackBar(context, content: Text(successMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_configError != null && _qrValue.isEmpty && _barcodeValue.isEmpty) {
      return Scaffold(
        backgroundColor: LexiColors.lightGray,
        appBar: const LexiAppBar(title: 'الدفع عبر شام كاش'),
        body: ErrorState(
          message: 'تعذر تحميل إعدادات شام كاش.',
          onRetry: _loadConfig,
        ),
      );
    }

    return Scaffold(
      backgroundColor: LexiColors.lightGray,
      appBar: const LexiAppBar(title: 'الدفع عبر شام كاش'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoadingConfig) ...[
              const LinearProgressIndicator(color: LexiColors.primary),
              const SizedBox(height: LexiSpacing.md),
            ],
            Container(
              padding: const EdgeInsets.all(LexiSpacing.lg),
              decoration: BoxDecoration(
                color: LexiColors.white,
                borderRadius: BorderRadius.circular(LexiRadius.md),
                border: Border.all(color: LexiColors.outline),
              ),
              child: Column(
                children: [
                  Text(
                    _accountName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: LexiSpacing.sm),
                  Text(
                    CurrencyFormatter.formatAmount(widget.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: LexiColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.lg),
                  if (_qrValue.isNotEmpty)
                    QrImageView(
                      data: _qrValue,
                      version: QrVersions.auto,
                      size: 200,
                    )
                  else
                    const Text('QR غير متوفر حالياً'),
                ],
              ),
            ),
            const SizedBox(height: LexiSpacing.lg),
            Container(
              padding: const EdgeInsets.all(LexiSpacing.md),
              decoration: BoxDecoration(
                color: LexiColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(LexiRadius.md),
                border: Border.all(
                  color: LexiColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: LexiColors.primary),
                      const SizedBox(width: LexiSpacing.sm),
                      Expanded(
                        child: Text(
                          _instructionsAr,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LexiSpacing.sm),
                  GestureDetector(
                    onTap: () {
                      _copyText(widget.orderId, 'تم نسخ رقم الطلب');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LexiSpacing.md,
                        vertical: LexiSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: LexiColors.white,
                        borderRadius: BorderRadius.circular(LexiRadius.sm),
                        border: Border.all(color: LexiColors.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#${widget.orderId}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: LexiSpacing.sm),
                          const Icon(
                            Icons.copy,
                            size: 16,
                            color: LexiColors.secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_barcodeValue.isNotEmpty) ...[
                    const SizedBox(height: LexiSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(LexiSpacing.md),
                      decoration: BoxDecoration(
                        color: LexiColors.white,
                        borderRadius: BorderRadius.circular(LexiRadius.sm),
                        border: Border.all(color: LexiColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نص الباركود (انسخه والصقه في شام كاش)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _barcodeValue,
                                  textDirection: TextDirection.ltr,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: LexiSpacing.sm),
                              IconButton(
                                tooltip: 'نسخ الباركود',
                                onPressed: () => _copyText(
                                  _barcodeValue,
                                  'تم نسخ نص الباركود',
                                ),
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: LexiSpacing.lg),
            Text('إثبات الدفع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: LexiSpacing.sm),
            if (_proofImage == null)
              AppButton(
                label: 'رفع صورة الإيصال',
                icon: Icons.camera_alt_outlined,
                onPressed: _pickImage,
                type: AppButtonType.secondary,
              )
            else ...[
              if (_proofBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                  child: Image.memory(
                    _proofBytes!,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: LexiSpacing.md),
              AppButton(
                label: 'تغيير الصورة',
                type: AppButtonType.text,
                onPressed: _pickImage,
              ),
              const SizedBox(height: LexiSpacing.md),
              AppButton(
                label: 'إرسال الإيصال',
                isLoading: _isUploading,
                onPressed: _uploadProof,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
