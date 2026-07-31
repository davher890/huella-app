import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/admin_device.dart';
import '../../models/admin_user.dart';

class UserDevicesScreen extends StatefulWidget {
  const UserDevicesScreen({super.key, required this.user});
  final AdminUser user;

  @override
  State<UserDevicesScreen> createState() => _UserDevicesScreenState();
}

class _UserDevicesScreenState extends State<UserDevicesScreen> {
  final _apiClient = ApiClient();
  late Future<List<AdminDevice>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _devicesFuture = _apiClient.fetchUserDevices(widget.user.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _devicesFuture = _apiClient.fetchUserDevices(widget.user.id);
    });
    await _devicesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.email)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AdminDevice>>(
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
                    child: Text('Este usuario no tiene devices asignados.'),
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
                  subtitle: Text(device.deviceId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
