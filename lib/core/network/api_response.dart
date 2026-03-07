/// Generic wrapper for Lexi API responses.
///
/// Every successful Lexi API response follows:
/// ```json
/// { "success": true, "data": { ... } }
/// ```
///
/// Every error response follows:
/// ```json
/// { "success": false, "error": { "code": "...", "message": "...", "status": 401 } }
/// ```
class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;

  const ApiResponse({required this.success, this.data, this.error});

  /// Parses a raw JSON map into [ApiResponse].
  ///
  /// [fromJsonT] converts the `data` field to [T].
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      error: json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Returns true if the response is a failure.
  bool get isError => !success || error != null;

  @override
  String toString() =>
      'ApiResponse(success: $success, data: $data, error: $error)';
}

/// Structured error from the Lexi API.
class ApiError {
  final String code;
  final String message;
  final int? status;

  const ApiError({required this.code, required this.message, this.status});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'خطأ غير معروف',
      status: json['status'] as int?,
    );
  }

  @override
  String toString() =>
      'ApiError(code: $code, message: $message, status: $status)';
}
