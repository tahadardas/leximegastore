import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/constants/endpoints.dart';
import '../errors/api_error_mapper.dart';
import '../errors/app_failure.dart';

class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final int? refreshExpiresIn;

  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.refreshExpiresIn,
  });
}

class AuthSessionResponse extends AuthTokens {
  final Map<String, dynamic>? user;

  const AuthSessionResponse({
    required super.accessToken,
    super.refreshToken,
    super.expiresIn,
    super.refreshExpiresIn,
    this.user,
  });
}

class AuthService {
  final Dio _dio;

  static String get _baseUrl => Endpoints.baseUrl;
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';
  static const _mobileAcceptLanguage = 'ar,en-US;q=0.9,en;q=0.8';
  static const _authLoginPathRestRoute =
      '/index.php?rest_route=/lexi/v1/auth/login';
  static const _authLoginPathWpJson = '/wp-json/lexi/v1/auth/login';
  static const _authRegisterPathRestRoute =
      '/index.php?rest_route=/lexi/v1/auth/register';
  static const _authRegisterPathWpJson = '/wp-json/lexi/v1/auth/register';
  static const _authRefreshPathRestRoute =
      '/index.php?rest_route=/lexi/v1/auth/refresh';
  static const _authRefreshPathWpJson = '/wp-json/lexi/v1/auth/refresh';
  static const _authLogoutPathRestRoute =
      '/index.php?rest_route=/lexi/v1/auth/logout';
  static const _authLogoutPathWpJson = '/wp-json/lexi/v1/auth/logout';
  static const _authMePathRestRoute = '/index.php?rest_route=/lexi/v1/auth/me';
  static const _authMePathWpJson = '/wp-json/lexi/v1/auth/me';
  static const _wpUsersMePathRestRoute =
      '/index.php?rest_route=/wp/v2/users/me&context=edit';
  static const _wpUsersMePathWpJson = '/wp-json/wp/v2/users/me?context=edit';
  static const _jwtTokenPathRestRoute =
      '/index.php?rest_route=/jwt-auth/v1/token';
  static const _jwtTokenPathWpJson = '/wp-json/jwt-auth/v1/token';
  static const _jwtValidatePathRestRoute =
      '/index.php?rest_route=/jwt-auth/v1/token/validate';
  static const _jwtValidatePathWpJson = '/wp-json/jwt-auth/v1/token/validate';

  AuthService(this._dio);

  Future<AuthSessionResponse> login(String username, String password) async {
    try {
      final response = await _postWithFallback(
        _routeCandidates(_authLoginPathRestRoute, _authLoginPathWpJson),
        data: {'username': username.trim(), 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );

      return _parseAuthSessionResponse(response.data);
    } on DioException catch (e) {
      if (_isLikelyMissingLexiAuthRoute(e)) {
        return _loginViaJwt(username, password);
      }
      throw AppFailure(ApiErrorMapper.map(e), _errorCodeFromDio(e));
    } catch (e) {
      if (e is AppFailure && _isLikelyMissingLexiAuthFailure(e)) {
        return _loginViaJwt(username, password);
      }
      throw AppFailure(ApiErrorMapper.map(e));
    }
  }

  Future<AuthSessionResponse> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
    String? phone,
    String? address1,
    String? city,
  }) async {
    try {
      final response = await _postWithFallback(
        _routeCandidates(_authRegisterPathRestRoute, _authRegisterPathWpJson),
        data: {
          'email': email.trim(),
          'password': password,
          if ((username ?? '').trim().isNotEmpty) 'username': username!.trim(),
          if ((firstName ?? '').trim().isNotEmpty)
            'first_name': firstName!.trim(),
          if ((lastName ?? '').trim().isNotEmpty) 'last_name': lastName!.trim(),
          if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
          if ((address1 ?? '').trim().isNotEmpty) 'address_1': address1!.trim(),
          if ((city ?? '').trim().isNotEmpty) 'city': city!.trim(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );

      return _parseAuthSessionResponse(response.data);
    } on DioException catch (e) {
      throw AppFailure(ApiErrorMapper.map(e), _errorCodeFromDio(e));
    } catch (e) {
      throw AppFailure(ApiErrorMapper.map(e));
    }
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final response = await _postWithFallback(
        _routeCandidates(_authRefreshPathRestRoute, _authRefreshPathWpJson),
        data: {'refresh_token': refreshToken.trim()},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );

      final payload = _extractPayloadMap(response.data);
      final accessToken = _extractAccessToken(payload);
      if (accessToken.isEmpty) {
        throw AppFailure('No access token received from refresh endpoint.');
      }

      final nextRefresh =
          (payload['refresh_token'] ?? '').toString().trim().isEmpty
          ? null
          : (payload['refresh_token'] ?? '').toString().trim();

      return AuthTokens(
        accessToken: accessToken,
        refreshToken: nextRefresh,
        expiresIn: _toInt(payload['expires_in']),
        refreshExpiresIn: _toInt(payload['refresh_expires_in']),
      );
    } on DioException catch (e) {
      if (_isLikelyMissingLexiAuthRoute(e)) {
        return _refreshViaJwtValidation(refreshToken);
      }
      throw AppFailure(ApiErrorMapper.map(e), _errorCodeFromDio(e));
    } catch (e) {
      if (e is AppFailure) {
        if (_isLikelyMissingLexiAuthFailure(e)) {
          return _refreshViaJwtValidation(refreshToken);
        }
        rethrow;
      }
      throw AppFailure(ApiErrorMapper.map(e));
    }
  }

  Future<void> logout({String? refreshToken, String? accessToken}) async {
    try {
      await _postWithFallback(
        _routeCandidates(_authLogoutPathRestRoute, _authLogoutPathWpJson),
        data: {
          if ((refreshToken ?? '').trim().isNotEmpty)
            'refresh_token': refreshToken!.trim(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            if ((accessToken ?? '').trim().isNotEmpty)
              'Authorization': 'Bearer ${accessToken!.trim()}',
          },
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return;
      }
      throw AppFailure(ApiErrorMapper.map(e), _errorCodeFromDio(e));
    } catch (e) {
      throw AppFailure(ApiErrorMapper.map(e));
    }
  }

  Future<Map<String, dynamic>> getMe(String accessToken) async {
    try {
      final response = await _getWithFallback(
        <String>[
          ..._routeCandidates(_authMePathRestRoute, _authMePathWpJson),
          ..._routeCandidates(_wpUsersMePathRestRoute, _wpUsersMePathWpJson),
        ],
        options: Options(
          headers: {'Authorization': 'Bearer ${accessToken.trim()}'},
        ),
      );

      final payload = _extractPayloadMap(response.data);
      final user = payload['user'];
      if (user is Map<String, dynamic>) {
        return _normalizeUserMap(user);
      }
      if (user is Map) {
        return _normalizeUserMap(
          user.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return _normalizeUserMap(payload);
    } on DioException catch (e) {
      throw AppFailure(ApiErrorMapper.map(e), _errorCodeFromDio(e));
    } catch (e) {
      if (e is AppFailure) {
        rethrow;
      }
      throw AppFailure(ApiErrorMapper.map(e));
    }
  }

  AuthSessionResponse _parseAuthSessionResponse(dynamic raw) {
    final payload = _extractPayloadMap(raw);
    final accessToken = _extractAccessToken(payload);
    if (accessToken.isEmpty) {
      throw AppFailure('No access token returned by server.');
    }

    final refreshTokenRaw = (payload['refresh_token'] ?? '').toString().trim();
    final userRaw = payload['user'];
    Map<String, dynamic>? user;
    if (userRaw is Map<String, dynamic>) {
      user = _normalizeUserMap(userRaw);
    } else if (userRaw is Map) {
      user = _normalizeUserMap(
        userRaw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return AuthSessionResponse(
      accessToken: accessToken,
      refreshToken: refreshTokenRaw.isEmpty ? null : refreshTokenRaw,
      expiresIn: _toInt(payload['expires_in']),
      refreshExpiresIn: _toInt(payload['refresh_expires_in']),
      user: user,
    );
  }

  String _extractAccessToken(Map<String, dynamic> payload) {
    final access = (payload['access_token'] ?? '').toString().trim();
    if (access.isNotEmpty) {
      return access;
    }
    return (payload['token'] ?? '').toString().trim();
  }

  Map<String, dynamic> _extractPayloadMap(dynamic raw) {
    final decoded = _decodeJsonLike(raw);
    if (decoded is! Map) {
      throw AppFailure('Invalid response payload.');
    }

    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    final success = map['success'];
    if (success == false) {
      final error = map['error'];
      if (error is Map) {
        final message = (error['message'] ?? 'Request failed.')
            .toString()
            .trim();
        final code = (error['status'] ?? error['code'] ?? '').toString();
        throw AppFailure(message.isEmpty ? 'Request failed.' : message, code);
      }
      throw AppFailure('Request failed.');
    }

    final data = map['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return map;
  }

  Future<Response<dynamic>> _postWithFallback(
    List<String> routes, {
    required dynamic data,
    Options? options,
  }) async {
    DioException? lastError;
    final requestOptions = _withClientIdentity(_webSafeOptions(options));
    final attempts = _buildUrlAttempts(routes);

    for (var i = 0; i < attempts.length; i++) {
      final isLast = i == attempts.length - 1;
      try {
        return await _dio.post(
          attempts[i],
          data: data,
          options: requestOptions,
        );
      } on DioException catch (e) {
        lastError = e;
        if (!isLast && _canTryFallbackPath(e)) {
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? DioException(requestOptions: RequestOptions(path: ''));
  }

  Future<Response<dynamic>> _getWithFallback(
    List<String> routes, {
    Options? options,
  }) async {
    DioException? lastError;
    final requestOptions = _withClientIdentity(_webSafeOptions(options));
    final attempts = _buildUrlAttempts(routes);

    for (var i = 0; i < attempts.length; i++) {
      final isLast = i == attempts.length - 1;
      try {
        return await _dio.get(attempts[i], options: requestOptions);
      } on DioException catch (e) {
        lastError = e;
        if (!isLast && _canTryFallbackPath(e)) {
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? DioException(requestOptions: RequestOptions(path: ''));
  }

  List<String> _routeCandidates(String restRoute, String wpJsonRoute) {
    // On web, /wp-json/* may fail preflight on some hosting/CDN stacks.
    if (kIsWeb) {
      return <String>[restRoute];
    }
    return <String>[restRoute, wpJsonRoute];
  }

  Options _webSafeOptions(Options? options) {
    final base = options ?? Options();
    return base.copyWith(responseType: ResponseType.plain);
  }

  Options _withClientIdentity(Options base) {
    final headers = <String, dynamic>{...?base.headers};
    _ensureHeader(headers, 'Accept', 'application/json');
    if (!kIsWeb) {
      _ensureHeader(headers, 'User-Agent', _mobileUserAgent);
      _ensureHeader(headers, 'Accept-Language', _mobileAcceptLanguage);
    }
    return base.copyWith(headers: headers);
  }

  void _ensureHeader(Map<String, dynamic> headers, String key, String value) {
    final exists = headers.keys.any(
      (existing) => existing.toLowerCase() == key.toLowerCase(),
    );
    if (!exists) {
      headers[key] = value;
    }
  }

  List<String> _buildUrlAttempts(List<String> routes) {
    final baseUri = Uri.parse(_baseUrl);
    final baseHost = baseUri.host.trim().toLowerCase();
    final hosts = <String>[baseHost];
    if (baseHost.startsWith('www.')) {
      hosts.add(baseHost.substring(4));
    } else {
      hosts.add('www.$baseHost');
    }

    final attempts = <String>[];
    for (final host in hosts) {
      for (final route in routes) {
        final normalizedRoute = route.startsWith('/') ? route : '/$route';
        attempts.add('${baseUri.scheme}://$host$normalizedRoute');
      }
    }
    return attempts.toSet().toList(growable: false);
  }

  Future<AuthSessionResponse> _loginViaJwt(
    String username,
    String password,
  ) async {
    final response = await _postWithFallback(
      _routeCandidates(_jwtTokenPathRestRoute, _jwtTokenPathWpJson),
      data: {'username': username.trim(), 'password': password},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: const {'Accept': 'application/json'},
      ),
    );

    final payload = _extractPayloadMap(response.data);
    final accessToken = _extractAccessToken(payload);
    if (accessToken.isEmpty) {
      throw AppFailure('No access token returned by JWT endpoint.');
    }

    final roleHint = (payload['role'] ?? payload['user_role'] ?? '').toString();
    final fallbackUser = _normalizeUserMap(<String, dynamic>{
      'email': (payload['user_email'] ?? '').toString(),
      'display_name': (payload['user_display_name'] ?? '').toString(),
      'user_login': (payload['user_nicename'] ?? username).toString(),
      'role': roleHint,
      'roles':
          payload['roles'] ??
          (roleHint.trim().isEmpty ? const <String>[] : <String>[roleHint]),
    });
    Map<String, dynamic> user = fallbackUser;
    try {
      final freshUser = await getMe(accessToken);
      if (freshUser.isNotEmpty) {
        user = _normalizeUserMap(<String, dynamic>{
          ...fallbackUser,
          ...freshUser,
        });
      }
    } catch (_) {
      // Keep login flow resilient when profile endpoints are unavailable.
    }

    return AuthSessionResponse(
      accessToken: accessToken,
      // JWT plugin has no refresh-token contract. Keep token as fallback
      // session key so legacy/partial backends still allow customer login.
      refreshToken: accessToken,
      expiresIn: _jwtExpiresIn(accessToken),
      user: user,
    );
  }

  Future<AuthTokens> _refreshViaJwtValidation(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw AppFailure('Refresh token is required.');
    }

    await _postWithFallback(
      _routeCandidates(_jwtValidatePathRestRoute, _jwtValidatePathWpJson),
      data: const <String, dynamic>{},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $normalized',
        },
      ),
    );

    return AuthTokens(
      accessToken: normalized,
      refreshToken: normalized,
      expiresIn: _jwtExpiresIn(normalized),
    );
  }

  Map<String, dynamic> _normalizeUserMap(Map<String, dynamic> raw) {
    final rolesRaw = raw['roles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      for (final entry in rolesRaw) {
        final value = entry.toString().trim();
        if (value.isNotEmpty) {
          roles.add(value);
        }
      }
    } else if (rolesRaw is String) {
      final value = rolesRaw.trim();
      if (value.isNotEmpty) {
        roles.add(value);
      }
    } else if (rolesRaw is Map) {
      for (final entry in rolesRaw.entries) {
        final allowed = entry.value == true || entry.value == 1;
        if (!allowed) {
          continue;
        }
        final value = entry.key.toString().trim();
        if (value.isNotEmpty) {
          roles.add(value);
        }
      }
    }

    final roleField = (raw['role'] ?? raw['user_role'] ?? '').toString().trim();
    if (roleField.isNotEmpty && !roles.contains(roleField)) {
      roles.add(roleField);
    }

    String avatarUrl = (raw['avatar_url'] ?? '').toString().trim();
    if (avatarUrl.isEmpty && raw['avatar_urls'] is Map) {
      final avatarMap = (raw['avatar_urls'] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final preferred =
          avatarMap['96'] ?? avatarMap['48'] ?? avatarMap['24'] ?? '';
      avatarUrl = preferred.toString().trim();
    }

    final email = (raw['email'] ?? '').toString().trim();
    final username =
        (raw['user_login'] ??
                raw['username'] ??
                raw['slug'] ??
                raw['user_nicename'] ??
                '')
            .toString()
            .trim();
    final displayName = (raw['display_name'] ?? raw['name'] ?? username)
        .toString()
        .trim();

    return <String, dynamic>{
      ...raw,
      'email': email,
      'user_login': username,
      'username': username,
      'role': roleField,
      'display_name': displayName,
      'roles': roles,
      'avatar_url': avatarUrl,
    };
  }

  int? _jwtExpiresIn(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return null;
      }
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is! Map) {
        return null;
      }
      final expRaw = payload['exp'];
      final exp = expRaw is int ? expRaw : int.tryParse('$expRaw');
      if (exp == null || exp <= 0) {
        return null;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final remaining = exp - now;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return null;
    }
  }

  bool _isLikelyMissingLexiAuthRoute(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status != 404 && status != 405) {
      return false;
    }
    return _looksLikeNoRouteBody(error.response?.data);
  }

  bool _isLikelyMissingLexiAuthFailure(AppFailure error) {
    final code = (error.code ?? '').toLowerCase();
    if (code == 'rest_no_route') {
      return true;
    }
    return _looksLikeNoRouteBody(error.message);
  }

  bool _looksLikeNoRouteBody(dynamic body) {
    final lower = (body ?? '').toString().toLowerCase();
    if (lower.trim().isEmpty) {
      return false;
    }
    return lower.contains('rest_no_route') ||
        lower.contains(
          'no route was found matching the url and request method',
        ) ||
        lower.contains('لم يتم العثور على مسار يتوافق مع الرابط');
  }

  dynamic _decodeJsonLike(dynamic raw) {
    if (raw is! String) {
      return raw;
    }

    final normalized = _stripUtf8Bom(raw).trimLeft();
    if (normalized.isEmpty) {
      return raw;
    }

    if (!(normalized.startsWith('{') || normalized.startsWith('['))) {
      return raw;
    }

    try {
      return jsonDecode(normalized);
    } catch (_) {
      return raw;
    }
  }

  String _stripUtf8Bom(String input) {
    if (input.isEmpty) {
      return input;
    }
    var start = 0;
    while (start < input.length && input.codeUnitAt(start) == 0xFEFF) {
      start++;
    }
    return start == 0 ? input : input.substring(start);
  }

  bool _canTryFallbackPath(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == null) {
      return true;
    }
    if (statusCode == 403) {
      return _looksLikeHtmlBlock(e.response);
    }
    return statusCode == 404 ||
        statusCode == 405 ||
        statusCode == 429 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  bool _looksLikeHtmlBlock(Response<dynamic>? response) {
    if (response == null) {
      return false;
    }
    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) {
      return true;
    }

    final raw = (response.data ?? '').toString().toLowerCase();
    return raw.contains('<!doctype html') ||
        raw.contains('<html') ||
        raw.contains('<meta name="robots"') ||
        raw.contains('<title>405');
  }

  String? _errorCodeFromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return statusCode.toString();
    }

    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'network';
      default:
        return null;
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
