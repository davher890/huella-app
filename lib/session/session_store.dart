import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _keyAccessToken = 'session_access_token';
  static const _keyUserEmail = 'session_user_email';
  static const _keyUserName = 'session_user_name';
  static const _keyRole = 'session_role';

  Future<void> save({
    required String accessToken,
    required String userEmail,
    required String role,
    String? userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyUserEmail, userEmail);
    await prefs.setString(_keyRole, role);
    if (userName != null) {
      await prefs.setString(_keyUserName, userName);
    } else {
      await prefs.remove(_keyUserName);
    }
  }

  Future<void> saveUserName(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, userName);
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<String?> readUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String?> readUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole) == 'admin';
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyRole);
  }
}
