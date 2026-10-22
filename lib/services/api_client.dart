
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Config/config_url.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _tokenKey = 'token';
  static const String _userKey = 'user';

  static const String _biometricEnabledKey =
      'biometric_login_enabled';
  static const String _biometricTokenKey =
      'biometric_login_token';
  static const String _biometricUserKey =
      'biometric_login_user';

  // Đọc token phiên đăng nhập hiện tại.
  static Future<String?> _getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Uri _uri(String endpoint) {
    final base = ConfigUrl.baseUrl.endsWith('/')
        ? ConfigUrl.baseUrl.substring(
      0,
      ConfigUrl.baseUrl.length - 1,
    )
        : ConfigUrl.baseUrl;

    final path =
    endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;

    return Uri.parse('$base/$path');
  }

  static Future<Map<String, String>> _headers({
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await _getToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static dynamic _decodeResponse(http.Response response) {
    final body = response.body.trim();

    dynamic data;

    if (body.isEmpty) {
      data = null;
    } else {
      try {
        data = jsonDecode(body);
      } catch (_) {
        data = body;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    debugPrint(
      'API ERROR: ${response.statusCode} ${response.request?.url}',
    );
    debugPrint('API RESPONSE: ${response.body}');

    String message =
        'Yêu cầu thất bại (${response.statusCode}).';

    if (data is Map) {
      message = (
          data['message'] ??
              data['Message'] ??
              data['title'] ??
              data['detail'] ??
              message
      ).toString();

      final errors = data['errors'];

      if (errors is Map) {
        final details = errors.values
            .expand((value) => value is List ? value : [value])
            .join('\n');

        if (details.isNotEmpty) {
          message = '$message\n$details';
        }
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    throw ApiException(response.statusCode, message);
  }

  static Future<dynamic> get(
      String endpoint, {
        bool authenticated = true,
      }) async {
    final response = await http.get(
      _uri(endpoint),
      headers: await _headers(authenticated: authenticated),
    );

    return _decodeResponse(response);
  }

  static Future<dynamic> post(
      String endpoint, {
        Map<String, dynamic>? body,
        bool authenticated = true,
      }) async {
    final response = await http.post(
      _uri(endpoint),
      headers: await _headers(authenticated: authenticated),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    debugPrint('API POST URL: ${response.request?.url}');
    debugPrint('API POST STATUS: ${response.statusCode}');
    debugPrint('API POST BODY: ${response.body}');

    return _decodeResponse(response);
  }

  static Future<dynamic> put(
      String endpoint, {
        Map<String, dynamic>? body,
        bool authenticated = true,
      }) async {
    final response = await http.put(
      _uri(endpoint),
      headers: await _headers(authenticated: authenticated),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decodeResponse(response);
  }

  static Future<dynamic> patch(
      String endpoint, {
        Map<String, dynamic>? body,
        bool authenticated = true,
      }) async {
    final response = await http.patch(
      _uri(endpoint),
      headers: await _headers(authenticated: authenticated),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decodeResponse(response);
  }

  static Future<dynamic> delete(
      String endpoint, {
        bool authenticated = true,
      }) async {
    final response = await http.delete(
      _uri(endpoint),
      headers: await _headers(authenticated: authenticated),
    );

    return _decodeResponse(response);
  }

  // Lưu phiên đăng nhập hiện tại vào kho lưu trữ an toàn.
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  // Đọc thông tin user của phiên đăng nhập hiện tại.
  static Future<Map<String, dynamic>?> getSavedUser() async {
    final raw = await _storage.read(key: _userKey);

    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw);

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<String?> getSavedToken() async {
    return _storage.read(key: _tokenKey);
  }

  // Kiểm tra đã bật đăng nhập vân tay chưa.
  static Future<bool> isBiometricLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Lưu bản sao phiên đăng nhập riêng cho tính năng vân tay.
  // Chỉ gọi hàm này sau khi người dùng đồng ý bật vân tay.
  static Future<void> enableBiometricLogin() async {
    final token = await _storage.read(key: _tokenKey);
    final user = await _storage.read(key: _userKey);

    if (token == null || token.isEmpty ||
        user == null || user.isEmpty) {
      throw const ApiException(
        401,
        'Không tìm thấy phiên đăng nhập để bật vân tay.',
      );
    }

    await _storage.write(
      key: _biometricTokenKey,
      value: token,
    );

    await _storage.write(
      key: _biometricUserKey,
      value: user,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, true);
  }

  // Khôi phục phiên sau khi xác thực sinh trắc học thành công.
  static Future<Map<String, dynamic>?> restoreBiometricSession() async {
    final enabled = await isBiometricLoginEnabled();

    if (!enabled) return null;

    final token = await _storage.read(key: _biometricTokenKey);
    final rawUser = await _storage.read(key: _biometricUserKey);

    if (token == null ||
        token.isEmpty ||
        rawUser == null ||
        rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);

      if (decoded is! Map) return null;

      final user = Map<String, dynamic>.from(decoded);

      // Khôi phục phiên hiện tại để các API tiếp tục sử dụng token.
      await saveSession(token: token, user: user);

      return user;
    } catch (_) {
      return null;
    }
  }

  // Tắt đăng nhập vân tay và xóa phiên dự phòng.
  static Future<void> disableBiometricLogin() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_biometricEnabledKey);

    await _storage.delete(key: _biometricTokenKey);
    await _storage.delete(key: _biometricUserKey);
  }

  // Đăng xuất phiên hiện tại.
  // Giữ thiết lập vân tay để người dùng có thể đăng nhập lại.
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
