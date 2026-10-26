import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'navigation.dart';
import 'screens/device_list_screen.dart';
import 'screens/login_screen.dart';
import 'session/session_store.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push notifications are an Android-only feature for now; there's no
  // Firebase Web app registered, so initializing here would just throw on
  // web (and did, until this guard was added).
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  runApp(const HorseTrackerApp());
}

class HorseTrackerApp extends StatelessWidget {
  const HorseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Huella GPS',
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SessionStore().readAccessToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final hasSession = snapshot.data != null;
        return hasSession ? const DeviceListScreen() : const LoginScreen();
      },
    );
  }
}
