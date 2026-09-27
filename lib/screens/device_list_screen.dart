import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/device.dart';
import '../push/push_notifications.dart';
import '../session/session_store.dart';
import 'account_screen.dart';
import 'admin/admin_screen.dart';
import 'all_devices_map_screen.dart';
import 'device_locations_screen.dart';
import 'login_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _apiClient = ApiClient();
  late Future<List<Device>> _devicesFuture;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _devicesFuture = _apiClient.fetchDevices();
    SessionStore().isAdmin().then((isAdmin) {
      if (mounted) setState(() => _isAdmin = isAdmin);
    });
    // Runs both right after a fresh login and on every app restart with a
    // saved session, so the token registered with the backend never goes
    // stale for long.
    PushNotifications.initAndRegister();
  }

  Future<void> _refresh() async {
    setState(() {
      _devicesFuture = _apiClient.fetchDevices();
    });
    await _devicesFuture;
  }

  Future<void> _logout(BuildContext context) async {
    await PushNotifications.unregister();
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Ver todos en el mapa',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AllDevicesMapScreen()),
              );
            },
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Administracion',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi cuenta',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Device>>(
          future: _devicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              );
            }

            final devices = snapshot.data ?? [];
            if (devices.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No tienes devices asociados todavia.'),
                  ),
                ],
              );
            }

            return ListView.separated(
              itemCount: devices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(device.name),
                  subtitle: Text(device.id),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceLocationsScreen(device: device),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}