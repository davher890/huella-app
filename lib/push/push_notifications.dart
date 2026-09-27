import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../navigation.dart';

// Requests notification permission, registers the device's FCM token with
// the backend (so it can push a "left the geofence" alert), and keeps that
// token in sync. Call initAndRegister() once the user is known to be logged
// in (fresh login, or app restart with a saved session); call unregister()
// on logout.
class PushNotifications {
  PushNotifications._();

  static bool _listenersAttached = false;

  static Future<void> initAndRegister() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint('PushNotifications: permission status = ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('PushNotifications: fcm token = $token');
    if (token != null) await _register(token);

    // Attached once per app run: onTokenRefresh/onMessage stay valid across
    // logins, there's nothing to tear down between one user and the next.
    if (!_listenersAttached) {
      _listenersAttached = true;
      FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    }
  }

  static Future<void> _register(String token) async {
    try {
      await ApiClient().registerPushToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      debugPrint('PushNotifications: token registered ($token)');
    } catch (e) {
      // Best-effort: this device just won't get alerts until the next
      // successful registration (next login, or the next token refresh).
      debugPrint('PushNotifications: failed to register token: $e');
    }
  }

  // FCM only shows a notification automatically when the app is backgrounded
  // or terminated; while it's in the foreground it has to be surfaced by
  // hand, so this shows it as a SnackBar instead.
  static void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final context = navigatorKey.currentContext;
    if (notification == null || context == null) return;

    final text = [notification.title, notification.body].whereType<String>().join(': ');
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
    );
  }

  static Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await ApiClient().unregisterPushToken(token);
      debugPrint('PushNotifications: token unregistered');
    } catch (e) {
      // Best-effort: worst case a stale token lingers until it's reassigned
      // to whoever logs into this device next.
      debugPrint('PushNotifications: failed to unregister token: $e');
    }
  }
}
