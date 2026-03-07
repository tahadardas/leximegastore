import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';

class AdminNotificationUiState {
  final bool isLoading;
  final bool isSavingSettings;
  final String? error;
  final Map<String, dynamic>? firebaseSettings;
  final List<Map<String, dynamic>> campaigns;
  final Map<String, dynamic>? lastCampaignResult;

  const AdminNotificationUiState({
    this.isLoading = false,
    this.isSavingSettings = false,
    this.error,
    this.firebaseSettings,
    this.campaigns = const <Map<String, dynamic>>[],
    this.lastCampaignResult,
  });

  AdminNotificationUiState copyWith({
    bool? isLoading,
    bool? isSavingSettings,
    String? error,
    bool clearError = false,
    Map<String, dynamic>? firebaseSettings,
    List<Map<String, dynamic>>? campaigns,
    Map<String, dynamic>? lastCampaignResult,
  }) {
    return AdminNotificationUiState(
      isLoading: isLoading ?? this.isLoading,
      isSavingSettings: isSavingSettings ?? this.isSavingSettings,
      error: clearError ? null : (error ?? this.error),
      firebaseSettings: firebaseSettings ?? this.firebaseSettings,
      campaigns: campaigns ?? this.campaigns,
      lastCampaignResult: lastCampaignResult ?? this.lastCampaignResult,
    );
  }
}

final adminNotificationControllerProvider =
    StateNotifierProvider<
      AdminNotificationController,
      AdminNotificationUiState
    >((ref) => AdminNotificationController(ref.read(dioClientProvider)));

class AdminNotificationController
    extends StateNotifier<AdminNotificationUiState> {
  final DioClient _dio;

  AdminNotificationController(this._dio)
    : super(const AdminNotificationUiState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Future.wait(<Future<void>>[
        loadFirebaseSettings(),
        loadCampaigns(),
      ]);
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractMessage(e, fallback: 'تعذّر تحميل إعدادات الإشعارات.'),
      );
    }
  }

  Future<void> loadFirebaseSettings() async {
    try {
      final response = await _dio.get(
        Endpoints.adminNotificationFirebaseSettings(),
      );
      final map = extractMap(response.data);
      state = state.copyWith(firebaseSettings: map, clearError: true);
    } catch (e) {
      state = state.copyWith(
        error: _extractMessage(e, fallback: 'تعذّر تحميل إعدادات Firebase.'),
      );
      rethrow;
    }
  }

  Future<void> saveFirebaseSettings({
    required bool enabled,
    required String fcmProjectId,
    required String fcmServiceAccountPath,
    required String defaultImageUrl,
    required String defaultOpenMode,
    required int ttlSeconds,
  }) async {
    state = state.copyWith(isSavingSettings: true, clearError: true);
    try {
      final response = await _dio.patch(
        Endpoints.adminNotificationFirebaseSettings(),
        data: <String, dynamic>{
          'enabled': enabled,
          'fcm_project_id': fcmProjectId.trim(),
          if (fcmServiceAccountPath.trim().isNotEmpty)
            'fcm_service_account_path': fcmServiceAccountPath.trim(),
          'default_image_url': defaultImageUrl.trim(),
          'default_open_mode': defaultOpenMode.trim(),
          'ttl_seconds': ttlSeconds,
        },
      );
      final map = extractMap(response.data);
      state = state.copyWith(
        isSavingSettings: false,
        firebaseSettings: map,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSavingSettings: false,
        error: _extractMessage(e, fallback: 'تعذّر حفظ إعدادات Firebase.'),
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> sendNotification({
    required String target,
    required String audience,
    required String titleAr,
    required String bodyAr,
    required String type,
    required String openMode,
    required bool sendPush,
    String? deepLink,
    String? imageUrl,
    int? userId,
    String? deviceId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _dio.post(
        Endpoints.adminSendNotification(),
        data: <String, dynamic>{
          'target': target,
          'audience': audience,
          'title_ar': titleAr.trim(),
          'body_ar': bodyAr.trim(),
          'type': type.trim(),
          'open_mode': openMode.trim(),
          'send_push': sendPush,
          if ((deepLink ?? '').trim().isNotEmpty) 'deep_link': deepLink!.trim(),
          if ((imageUrl ?? '').trim().isNotEmpty) 'image_url': imageUrl!.trim(),
          if (userId != null && userId > 0) 'user_id': userId,
          if ((deviceId ?? '').trim().isNotEmpty) 'device_id': deviceId!.trim(),
        },
      );

      final map = extractMap(response.data);
      final campaign = map['campaign'] is Map
          ? Map<String, dynamic>.from(map['campaign'] as Map)
          : null;

      await loadCampaigns();
      state = state.copyWith(
        isLoading: false,
        lastCampaignResult: campaign,
        clearError: true,
      );
      return campaign;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractMessage(e, fallback: 'تعذّر إرسال الإشعار.'),
      );
      rethrow;
    }
  }

  Future<void> loadCampaigns({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get(
        Endpoints.adminNotificationCampaigns(),
        queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
      );
      final map = extractMap(response.data);
      final rawItems = map['items'] as List? ?? const <dynamic>[];
      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

      state = state.copyWith(campaigns: items, clearError: true);
    } catch (e) {
      state = state.copyWith(
        error: _extractMessage(e, fallback: 'تعذّر تحميل سجل الحملات.'),
      );
      rethrow;
    }
  }

  String _extractMessage(Object error, {required String fallback}) {
    if (error is DioException) {
      final payload = extractMap(error.response?.data);
      final nested = extractMap(payload['error']);
      final message = (nested['message'] ?? payload['message'] ?? '')
          .toString()
          .trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}
