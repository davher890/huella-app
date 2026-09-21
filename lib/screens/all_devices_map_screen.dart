import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/api_client.dart';
import '../models/device.dart';
import '../models/location_point.dart';
import '../utils/palette.dart';

class _DeviceTrail {
  const _DeviceTrail({required this.device, required this.locations});
  final Device device;
  final List<LocationPoint> locations;
}

class AllDevicesMapScreen extends StatefulWidget {
  const AllDevicesMapScreen({super.key});

  @override
  State<AllDevicesMapScreen> createState() => _AllDevicesMapScreenState();
}

class _AllDevicesMapScreenState extends State<AllDevicesMapScreen> {
  final _apiClient = ApiClient();
  late Future<List<_DeviceTrail>> _trailsFuture;

  @override
  void initState() {
    super.initState();
    _trailsFuture = _loadTrails();
  }

  Future<List<_DeviceTrail>> _loadTrails() async {
    final devices = await _apiClient.fetchDevices();
    return Future.wait(devices.map((device) async {
      try {
        final locations = await _apiClient.fetchLocations(device.id);
        return _DeviceTrail(device: device, locations: locations);
      } catch (_) {
        // If one device fails to load, still show the rest.
        return _DeviceTrail(device: device, locations: const []);
      }
    }));
  }

  Future<void> _refresh() async {
    setState(() {
      _trailsFuture = _loadTrails();
    });
    await _trailsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de todos los devices')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_DeviceTrail>>(
          future: _trailsFuture,
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

            final trails = (snapshot.data ?? []).where((t) => t.locations.isNotEmpty).toList();
            if (trails.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay localizaciones registradas para ninguno de tus devices todavia.'),
                  ),
                ],
              );
            }

            return _AllDevicesMap(trails: trails);
          },
        ),
      ),
    );
  }
}

class _AllDevicesMap extends StatelessWidget {
  const _AllDevicesMap({required this.trails});
  final List<_DeviceTrail> trails;

  @override
  Widget build(BuildContext context) {
    final allPoints = <ll.LatLng>[
      for (final trail in trails)
        for (final loc in trail.locations) ll.LatLng(loc.latitude, loc.longitude),
    ];

    final mapOptions = allPoints.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(allPoints),
              padding: const EdgeInsets.all(48),
            ),
          )
        : MapOptions(
            initialCenter: allPoints.first,
            initialZoom: 15,
          );

    return Stack(
      children: [
        FlutterMap(
          options: mapOptions,
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.the_horse_tracker_app',
            ),
            PolylineLayer(
              polylines: [
                for (var i = 0; i < trails.length; i++)
                  if (trails[i].locations.length > 1)
                    Polyline(
                      // Backend returns most-recent-first; reverse for a
                      // chronological path.
                      points: trails[i]
                          .locations
                          .reversed
                          .map((l) => ll.LatLng(l.latitude, l.longitude))
                          .toList(),
                      strokeWidth: 4,
                      color: colorForIndex(i),
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < trails.length; i++)
                  Marker(
                    point: ll.LatLng(
                      trails[i].locations.first.latitude,
                      trails[i].locations.first.longitude,
                    ),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showDeviceInfo(context, trails[i]),
                      child: Icon(Icons.location_on, color: colorForIndex(i), size: 40),
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
        Positioned(left: 12, right: 12, bottom: 12, child: _DevicesLegend(trails: trails)),
      ],
    );
  }

  void _showDeviceInfo(BuildContext context, _DeviceTrail trail) {
    final latest = trail.locations.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${trail.device.name}: ${latest.recordedAt?.toLocal() ?? 'sin fecha'} '
          '(${latest.latitude.toStringAsFixed(5)}, ${latest.longitude.toStringAsFixed(5)})',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _DevicesLegend extends StatelessWidget {
  const _DevicesLegend({required this.trails});
  final List<_DeviceTrail> trails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var i = 0; i < trails.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: colorForIndex(i), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(trails[i].device.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}
