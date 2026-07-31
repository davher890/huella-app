import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _keyAccessToken = 'session_access_token';
  static const _keyUserEmail = 'session_user_email';
  static const _keyRole = 'session_role';

  Future<void> save({
    required String accessToken,
    required String userEmail,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyUserEmail, userEmail);
    await prefs.setString(_keyRole, role);
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<String?> readUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole) == 'admin';
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyRole);
  }
}
