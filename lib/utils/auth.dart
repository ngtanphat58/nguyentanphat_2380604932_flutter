
import '../Models/app_models.dart';
import '../Services/api_client.dart';

class AuthUtils {
  AuthUtils._();

  static Future<AppUser?> getCurrentUser() async {
    final data = await ApiClient.getSavedUser();

    if (data == null) return null;

    return AppUser.fromJson(data);
  }

  static Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();

    if (user == null) return false;

    final tokenUser = await ApiClient.getSavedUser();
    return tokenUser != null;
  }

  static Future<bool> isParent() async {
    final user = await getCurrentUser();

    if (user == null) return false;

    return user.roles.any(
          (role) => role.toLowerCase() == 'parent',
    );
  }

  static Future<bool> isChild() async {
    final user = await getCurrentUser();

    if (user == null) return false;

    return user.isChild;
  }

  static Future<void> logout() async {
    await ApiClient.logout();
  }
}
