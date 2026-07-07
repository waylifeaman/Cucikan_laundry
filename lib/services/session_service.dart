import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Future<void> saveLogin({
    required String outletId,
    required String userId,
    required String userName,
    required String role,
    required String outletName,
    required String outletCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('outletId', outletId);
    await prefs.setString('userId', userId);
    await prefs.setString('userName', userName);
    await prefs.setString('role', role);
    await prefs.setString('outletName', outletName);
    await prefs.setString('outletCode', outletCode);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool('isLoggedIn') ?? false;
  }

  static Future<String> getOutletId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('outletId') ?? '';
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('userId') ?? '';
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('role') ?? '';
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('userName') ?? '';
  }

  static Future<String> getOutletName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('outletName') ?? '';
  }

  static Future<String> getOutletCode() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('outletCode') ?? '';
  }
}
