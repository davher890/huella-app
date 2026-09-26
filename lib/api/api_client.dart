import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/admin_device.dart';
import '../models/admin_user.dart';
import '../models/device.dart';
import '../models/location_point.dart';
import '../navigation.dart';
import '../screens/login_screen.dart';
import '../session/session_store.dart';

// const apiBaseUrl = 'http://192.168.18.2:3000';
const apiBaseUrl = 'https://the-horse-tracker-api.vercel.app';

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
    this.userName,
  });
  final String userEmail;
  final String accessToken;
  final String role;
  final String? userName;
}

// Guards against redirecting to LoginScreen more than once if several
// requests come back with 401 around the same time.
bool _redirectingToLogin = false;

Future<void> _handleUnauthorized() async {
  if (_redirectingToLogin) return;
  _redirectingToLogin = true;

  await SessionStore().clear();
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

class ApiClient {
  Future<Map<String, String>> _authHeaders() async {
    final accessToken = await SessionStore().readAccessToken();
    if (accessToken == null) {
      throw ApiException('No hay sesion activa');
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  // Every authenticated request goes through here so a 401 (expired or
  // invalid session) is handled in a single place: redirect to LoginScreen
  // instead of leaving each screen to fail individually.
  Future<http.Response> _send(Future<http.Response> Function() send) async {
    final res = await send().timeout(const Duration(seconds: 15));
    if (res.statusCode == 401) {
      _handleUnauthorized();
      throw ApiException('Sesion expirada, vuelve a iniciar sesion');
    }
    return res;
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
    final userMetadata = user?['user_metadata'] as Map<String, dynamic>?;

    // A fresh login means any earlier 401 redirect no longer applies.
    _redirectingToLogin = false;

    return LoginResult(
      userEmail: user?['email'] as String? ?? email,
      accessToken: accessToken,
      role: appMetadata?['role'] as String? ?? 'user',
      userName: userMetadata?['name'] as String?,
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/api/user'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password, 'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo crear la cuenta');
    }
  }

  Future<void> updateProfile({String? name, String? password}) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (password != null) 'password': password,
    };

    final res = await _send(() => http.patch(
          Uri.parse('$apiBaseUrl/api/user'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ));

    if (res.statusCode != 200) {
      final responseBody = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(responseBody['error'] as String? ?? 'No se pudo actualizar el perfil');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/api/password-reset'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo enviar el email de recuperacion');
    }
  }

  Future<List<Device>> fetchDevices() async {
    final res = await _send(() async => http.get(
          Uri.parse('$apiBaseUrl/api/devices'),
          headers: await _authHeaders(),
        ));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener los dispositivos');
    }

    final devices = body['devices'] as List<dynamic>? ?? [];
    return devices
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LocationPoint>> fetchLocations(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final queryParams = <String, String>{
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (limit != null) 'limit': limit.toString(),
    };
    final uri = Uri.parse('$apiBaseUrl/api/devices/$deviceId/locations')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final res = await _send(() async => http.get(uri, headers: await _authHeaders()));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener las localizaciones');
    }

    final locations = body['locations'] as List<dynamic>? ?? [];
    return locations
        .map((e) => LocationPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Distance in meters covered between the first and last location in the
  // given range (or the whole history if from/to are omitted).
  Future<double> fetchDeviceDistance(String deviceId, {DateTime? from, DateTime? to}) async {
    final queryParams = <String, String>{
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$apiBaseUrl/api/devices/$deviceId/statistics')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final res = await _send(() async => http.get(uri, headers: await _authHeaders()));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener las estadisticas');
    }

    return (body['distance'] as num?)?.toDouble() ?? 0;
  }

  Future<List<LatLng>?> fetchGeofence(String deviceId) async {
    final res = await _send(() async => http.get(
          Uri.parse('$apiBaseUrl/api/devices/$deviceId/geofence'),
          headers: await _authHeaders(),
        ));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudo obtener la zona guardada');
    }

    final geofence = body['geofence'] as Map<String, dynamic>?;
    if (geofence == null) return null;

    final points = geofence['points'] as List<dynamic>? ?? [];
    return points
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();
  }

  Future<void> saveGeofence(String deviceId, List<LatLng> points) async {
    final headers = await _authHeaders();
    final res = await _send(() => http.post(
          Uri.parse('$apiBaseUrl/api/devices/$deviceId/geofence'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'points': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
          }),
        ));

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo guardar la zona');
    }
  }

  Future<List<AdminUser>> fetchAdminUsers() async {
    final res = await _send(() async => http.get(
          Uri.parse('$apiBaseUrl/api/admin/users'),
          headers: await _authHeaders(),
        ));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'No se pudieron obtener los usuarios');
    }

    final users = body['users'] as List<dynamic>? ?? [];
    return users
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteUser(String userId) async {
    final headers = await _authHeaders();
    final res = await _send(() => http.delete(
          Uri.parse('$apiBaseUrl/api/admin/users/$userId'),
          headers: headers,
        ));

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo eliminar el usuario');
    }
  }

  Future<List<AdminDevice>> fetchUserDevices(String userId) async {
    final res = await _send(() async => http.get(
          Uri.parse('$apiBaseUrl/api/admin/users/$userId/devices'),
          headers: await _authHeaders(),
        ));

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
    final res = await _send(() async => http.get(
          Uri.parse('$apiBaseUrl/api/admin/devices'),
          headers: await _authHeaders(),
        ));

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
    final res = await _send(() => http.post(
          Uri.parse('$apiBaseUrl/api/admin/user-devices'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'deviceId': deviceDbId}),
        ));

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo asignar el device');
    }
  }

  Future<void> createDevice({required String deviceId, required String name}) async {
    final headers = await _authHeaders();
    final res = await _send(() => http.post(
          Uri.parse('$apiBaseUrl/api/admin/devices'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId, 'name': name}),
        ));

    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? 'No se pudo crear el device');
    }
  }
}
