
import '../Models/app_models.dart';
import 'api_client.dart';

class AuthService {
  AuthService._();

  static Future<Map<String, dynamic>> registerParent({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await ApiClient.post(
      'Auth/register',
      authenticated: false,
      body: {
        'fullName': fullName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      },
    );

    return _asMap(result);
  }

  static Future<Map<String, dynamic>> verifyParentEmail({
    required String email,
    required String otp,
  }) async {
    final result = await ApiClient.post(
      'Auth/verify-email',
      authenticated: false,
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
      },
    );

    return _asMap(result);
  }

  static Future<Map<String, dynamic>> registerChild({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String linkCode,
  }) async {
    final result = await ApiClient.post(
      'Auth/register-child',
      authenticated: false,
      body: {
        'fullName': fullName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'linkCode': linkCode.trim(),
      },
    );

    return _asMap(result);
  }

  static Future<Map<String, dynamic>> verifyChildEmail({
    required String email,
    required String otp,
  }) async {
    final result = await ApiClient.post(
      'Auth/verify-child-email',
      authenticated: false,
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
      },
    );

    return _asMap(result);
  }

  /// Bước 1: kiểm tra username/email + mật khẩu và yêu cầu OTP.
  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final result = await ApiClient.post(
      'Auth/login',
      authenticated: false,
      body: {
        'login': login.trim(),
        'password': password,
      },
    );

    final data = _asMap(result);

    if (data['requiresOtp'] != true) {
      throw const ApiException(
        500,
        'API không trả về requiresOtp như mong đợi.',
      );
    }

    return data;
  }

  /// Bước 2: xác minh OTP và lưu JWT + user.
  static Future<AppUser> verifyLoginOtp({
    required String login,
    required String otp,
  }) async {
    final result = await ApiClient.post(
      'Auth/verify-login-otp',
      authenticated: false,
      body: {
        'login': login.trim(),
        'otp': otp.trim(),
      },
    );

    final data = _asMap(result);
    final token = (data['token'] ?? '').toString();
    final rawUser = data['user'];

    if (token.isEmpty || rawUser is! Map) {
      throw const ApiException(
        500,
        'API không trả về token hoặc thông tin user hợp lệ.',
      );
    }

    final userMap = Map<String, dynamic>.from(rawUser);
    final user = AppUser.fromJson(userMap);

    await ApiClient.saveSession(
      token: token,
      user: user.toJson(),
    );

    return user;
  }
  static Future<Map<String, dynamic>> linkExistingChild({
    required String email,
    required String password,
    required String linkCode,
  }) async {
    final result = await ApiClient.post(
      'Auth/link-existing-child',
      authenticated: false,
      body: {
        'email': email.trim(),
        'password': password,
        'linkCode': linkCode.trim(),
      },
    );

    return _asMap(result);
  }
  static Future<void> logout() async {
    await ApiClient.logout();
  }

  static Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw const ApiException(
      500,
      'Dữ liệu trả về từ API không đúng định dạng JSON object.',
    );
  }
}
