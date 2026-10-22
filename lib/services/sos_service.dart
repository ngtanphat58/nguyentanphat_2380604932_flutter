
import '../Services/api_client.dart';
import '../Services/device_services.dart';

class SosService {
  SosService._();

  static Future<dynamic> sendSos() async {
    double? latitude;
    double? longitude;

    try {
      final position =
      await DeviceServices.getCurrentLocation();

      latitude = position.latitude;
      longitude = position.longitude;
    } catch (_) {
      // Vẫn gửi SOS nếu GPS tạm thời không lấy được.
    }

    return ApiClient.post(
      'Child/my-sos',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'message': 'Trẻ cần trợ giúp khẩn cấp!',
      },
    );
  }
}
