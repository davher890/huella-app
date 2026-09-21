import 'package:flutter/material.dart';

import 'navigation.dart';
import 'screens/device_list_screen.dart';
import 'screens/login_screen.dart';
import 'session/session_store.dart';

void main() {
  runApp(const HorseTrackerApp());
}

class HorseTrackerApp extends StatelessWidget {
  const HorseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Horse Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2d4a34)),
        useMaterial3: true,
      ),
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
