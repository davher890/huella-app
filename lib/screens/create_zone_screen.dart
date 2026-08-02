import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/api_client.dart';
import '../models/device.dart';

class CreateZoneScreen extends StatefulWidget {
  const CreateZoneScreen({super.key, required this.device, this.initialCenter});
  final Device device;
  final ll.LatLng? initialCenter;

  @override
  State<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends State<CreateZoneScreen> {
  final _apiClient = ApiClient();
  final List<ll.LatLng> _points = [];
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await _apiClient.fetchGeofence(widget.device.id);
      if (!mounted) return;
      setState(() {
        if (existing != null) _points.addAll(existing);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la zona guardada: $e')),
      );
    }
  }

  void _addPoint(ll.LatLng point) {
    if (_saving) return;
    setState(() => _points.add(point));
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clear() {
    if (_points.isEmpty) return;
    setState(() => _points.clear());
  }

  Future<void> _save() async {
    if (_points.length < 3) return;

    setState(() => _saving = true);
    try {
      await _apiClient.saveGeofence(widget.device.id, _points);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter ??
        (_points.isNotEmpty ? _points.first : const ll.LatLng(40.4168, -3.7038));

    return Scaffold(
      appBar: AppBar(
        title: Text('Zona de ${widget.device.name}'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            tooltip: 'Guardar zona',
            onPressed: (_points.length < 3 || _saving) ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Toca el mapa para marcar los vertices del perimetro (minimo 3).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                      onTap: (_, point) => _addPoint(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.the_horse_tracker_app',
                      ),
                      if (_points.length >= 3)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _points,
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderColor: Colors.blue,
                              borderStrokeWidth: 3,
                            ),
                          ],
                        )
                      else if (_points.length == 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _points, strokeWidth: 3, color: Colors.blue),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (var i = 0; i < _points.length; i++)
                            Marker(
                              point: _points[i],
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_points.isEmpty || _saving) ? null : _undo,
                            icon: const Icon(Icons.undo),
                            label: const Text('Deshacer'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_points.isEmpty || _saving) ? null : _clear,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Limpiar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
