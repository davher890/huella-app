import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/admin_device.dart';
import '../../models/admin_user.dart';
import 'create_device_screen.dart';
import 'user_devices_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _apiClient = ApiClient();
  late Future<List<AdminUser>> _usersFuture;
  late Future<List<AdminDevice>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _usersFuture = _apiClient.fetchAdminUsers();
    _devicesFuture = _apiClient.fetchAdminDevices();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_usersFuture, _devicesFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administracion'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usuarios'),
              Tab(text: 'Devices'),
              Tab(text: 'Asignar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersTab(usersFuture: _usersFuture, onRefresh: _refresh),
            _DevicesTab(devicesFuture: _devicesFuture, onRefresh: _refresh),
            _AssignTab(
              usersFuture: _usersFuture,
              devicesFuture: _devicesFuture,
              apiClient: _apiClient,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.usersFuture, required this.onRefresh});
  final Future<List<AdminUser>> usersFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<List<AdminUser>>(
        future: usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorList(message: snapshot.error.toString());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const _EmptyList(message: 'No hay usuarios registrados.');
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user.email),
                trailing: Chip(label: Text(user.role)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => UserDevicesScreen(user: user)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({required this.devicesFuture, required this.onRefresh});
  final Future<List<AdminDevice>> devicesFuture;
  final Future<void> Function() onRefresh;

  Future<void> _openCreateDevice(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateDeviceScreen()),
    );
    if (created == true) {
      await onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDevice(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo device'),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: FutureBuilder<List<AdminDevice>>(
          future: devicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorList(message: snapshot.error.toString());
            }
            final devices = snapshot.data ?? [];
            if (devices.isEmpty) {
              return const _EmptyList(message: 'No hay devices creados.');
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

class _AssignTab extends StatefulWidget {
  const _AssignTab({
    required this.usersFuture,
    required this.devicesFuture,
    required this.apiClient,
  });

  final Future<List<AdminUser>> usersFuture;
  final Future<List<AdminDevice>> devicesFuture;
  final ApiClient apiClient;

  @override
  State<_AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<_AssignTab> {
  String? _selectedUserId;
  int? _selectedDeviceDbId;
  bool _assigning = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _assign() async {
    if (_selectedUserId == null || _selectedDeviceDbId == null) return;
    setState(() {
      _assigning = true;
      _message = null;
    });
    try {
      await widget.apiClient.assignDevice(
        userId: _selectedUserId!,
        deviceDbId: _selectedDeviceDbId!,
      );
      setState(() {
        _message = 'Device asignado correctamente';
        _messageIsError = false;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([widget.usersFuture, widget.devicesFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorList(message: snapshot.error.toString());
        }

        final users = snapshot.data![0] as List<AdminUser>;
        final devices = snapshot.data![1] as List<AdminDevice>;

        if (users.isEmpty || devices.isEmpty) {
          return const _EmptyList(
            message: 'Hace falta al menos un usuario y un device para poder asignar.',
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedUserId,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                ),
                items: users
                    .map((u) => DropdownMenuItem(value: u.id, child: Text(u.email)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUserId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedDeviceDbId,
                decoration: const InputDecoration(
                  labelText: 'Device',
                  border: OutlineInputBorder(),
                ),
                items: devices
                    .map((d) => DropdownMenuItem(
                          value: d.dbId,
                          child: Text('${d.name} (${d.deviceId})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDeviceDbId = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_selectedUserId != null &&
                        _selectedDeviceDbId != null &&
                        !_assigning)
                    ? _assign
                    : null,
                child: _assigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Asignar'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError
                        ? Theme.of(context).colorScheme.error
                        : Colors.green,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $message',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message),
        ),
      ],
    );
  }
}
