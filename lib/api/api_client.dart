import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/admin_device.dart';
import '../models/admin_user.dart';
import '../models/device.dart';
import '../models/location_point.dart';
import '../session/session_store.dart';

const apiBaseUrl = 'http://192.168.18.2:3000'; // 'https://the-horse-tracker-api.vercel.app';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LoginResult {
  LoginResult({
    required this.userEmail,
    required this.accessToken,
    required this.role,
  });
  final String userEmail;
  final String accessToken;
  final String role;
}

class ApiClient {
  Future<Map<String, String>> _authHeaders() async {
    final accessToken = await SessionStore().readAccessToken();
    if (accessToken == null) {
      throw ApiException('No hay sesion activa');
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<LoginResult> login(String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'Login fallido');
    }

    final user = body['user'] as Map<String, dynamic>?;
    final session = body['session'] as Map<String, dynamic>?;
    final accessToken = session?['access_token'] as String?;

    if (accessToken == null) {
      throw ApiException('Respuesta de login invalida');
    }

    final appMetadata = user?['app_metadata'] as Map<String, dynamic>?;

    return LoginResult(
      userEmail: user?['email'] as String? ?? email,
      accessToken: accessToken,
      role: appMetadata?['role'] as String? ?? 'user',
    );
  }

  Future<List<Device>> fetchDevices() async {
    final res = await http
        .get(
          Uri.parse('$apiBaseUrl/api/devices'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener los dispositivos');
    }

    final devices = body['devices'] as List<dynamic>? ?? [];
    return devices
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LocationPoint>> fetchLocations(String deviceId) async {
    final res = await http
        .get(Uri.parse('$apiBaseUrl/api/devices/$deviceId/locations'))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener las localizaciones');
    }

    final locations = body['locations'] as List<dynamic>? ?? [];
    return locations
        .map((e) => LocationPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminUser>> fetchAdminUsers() async {
    final res = await http
        .get(
          Uri.parse('$apiBaseUrl/api/admin/users'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener los usuarios');
    }

    final users = body['users'] as List<dynamic>? ?? [];
    return users
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminDevice>> fetchUserDevices(String userId) async {
    final res = await http
        .get(
          Uri.parse('$apiBaseUrl/api/admin/users/$userId/devices'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener los devices del usuario');
    }

    final devices = body['devices'] as List<dynamic>? ?? [];
    return devices
        .map((e) => AdminDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminDevice>> fetchAdminDevices() async {
    final res = await http
        .get(
          Uri.parse('$apiBaseUrl/api/admin/devices'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener los devices');
    }

    final devices = body['devices'] as List<dynamic>? ?? [];
    return devices
        .map((e) => AdminDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> assignDevice({required String userId, required int deviceDbId}) async {
    final headers = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/api/admin/user-devices'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'deviceId': deviceDbId}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo asignar el device');
    }
  }

  Future<void> createDevice({required String deviceId, required String name}) async {
    final headers = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/api/admin/devices'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId, 'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo crear el device');
    }
  }
}
