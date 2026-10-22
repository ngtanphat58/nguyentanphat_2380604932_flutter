
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';

class DeviceServices {
  DeviceServices._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Chỉ lấy GPS khi người dùng chủ động gọi hàm.
  static Future<Position> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception('Hãy bật dịch vụ định vị trên điện thoại.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Ứng dụng chưa được cấp quyền vị trí.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở Cài đặt để cấp quyền.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
  }

  /// Xác thực sinh trắc học cục bộ.
  static Future<bool> authenticateWithBiometrics() async {
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;

    if (!supported) {
      throw Exception(
        'Thiết bị không hỗ trợ xác thực sinh trắc học.',
      );
    }

    if (!canCheck) {
      throw Exception(
        'Thiết bị chưa thiết lập vân tay hoặc sinh trắc học.',
      );
    }

    final biometrics = await _auth.getAvailableBiometrics();

    if (biometrics.isEmpty) {
      throw Exception(
        'Không tìm thấy vân tay khả dụng trên thiết bị.',
      );
    }

    return await _auth.authenticate(
      localizedReason: 'Xác thực để mở khóa ParentShield',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}
