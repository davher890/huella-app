import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/api_client.dart';
import '../models/device.dart';
import '../models/location_point.dart';

class DeviceLocationsScreen extends StatefulWidget {
  const DeviceLocationsScreen({super.key, required this.device});
  final Device device;

  @override
  State<DeviceLocationsScreen> createState() => _DeviceLocationsScreenState();
}

class _DeviceLocationsScreenState extends State<DeviceLocationsScreen> {
  final _apiClient = ApiClient();
  late Future<List<LocationPoint>> _locationsFuture;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _locationsFuture = _apiClient.fetchLocations(widget.device.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _locationsFuture = _apiClient.fetchLocations(widget.device.id);
    });
    await _locationsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: Icon(_showList ? Icons.map_outlined : Icons.list),
            tooltip: _showList ? 'Ver mapa' : 'Ver lista',
            onPressed: () => setState(() => _showList = !_showList),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<LocationPoint>>(
          future: _locationsFuture,
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

            final locations = snapshot.data ?? [];
            if (locations.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay localizaciones registradas para este device.'),
                  ),
                ],
              );
            }

            return _showList
                ? _LocationsList(locations: locations)
                : _RouteMap(locations: locations);
          },
        ),
      ),
    );
  }
}

class _LocationsList extends StatelessWidget {
  const _LocationsList({required this.locations});
  final List<LocationPoint> locations;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: locations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final loc = locations[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text('${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'),
          subtitle: Text(loc.recordedAt?.toLocal().toString() ?? 'sin fecha'),
          trailing: loc.speed != null ? Text('${loc.speed!.toStringAsFixed(1)} m/s') : null,
        );
      },
    );
  }
}

// El backend devuelve las localizaciones de mas reciente a mas antigua;
// para pintar el recorrido en orden cronologico hay que invertirlas.
class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.locations});
  final List<LocationPoint> locations;

  List<LocationPoint> get _chronological => locations.reversed.toList();

  Color _colorForIndex(int index, int count) {
    if (count <= 1) return Colors.orange;
    final t = index / (count - 1);
    return Color.lerp(Colors.blue, Colors.deepOrange, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final points = _chronological;
    final latLngPoints = points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
    final lastIndex = points.length - 1;

    final mapOptions = latLngPoints.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(latLngPoints),
              padding: const EdgeInsets.all(48),
            ),
          )
        : MapOptions(
            initialCenter: latLngPoints.first,
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
            if (latLngPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(points: latLngPoints, strokeWidth: 4, color: Colors.blueGrey),
                ],
              ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < points.length; i++)
                  Marker(
                    point: latLngPoints[i],
                    width: i == 0 || i == lastIndex ? 40 : 16,
                    height: i == 0 || i == lastIndex ? 40 : 16,
                    child: GestureDetector(
                      onTap: () => _showPointInfo(context, points[i]),
                      child: _MarkerIcon(
                        index: i,
                        isFirst: i == 0,
                        isLast: i == lastIndex,
                        color: _colorForIndex(i, points.length),
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
        const Positioned(left: 12, bottom: 12, child: _Legend()),
      ],
    );
  }

  void _showPointInfo(BuildContext context, LocationPoint point) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${point.recordedAt?.toLocal() ?? 'sin fecha'}  '
          '(${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  const _MarkerIcon({
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.color,
  });

  final int index;
  final bool isFirst;
  final bool isLast;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (isFirst) {
      return const Icon(Icons.flag, color: Colors.green, size: 32);
    }
    if (isLast) {
      return const Icon(Icons.location_on, color: Colors.red, size: 36);
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, color: Colors.green, size: 16),
          SizedBox(width: 4),
          Text('Inicio', style: TextStyle(fontSize: 12)),
          SizedBox(width: 12),
          Icon(Icons.location_on, color: Colors.red, size: 16),
          SizedBox(width: 4),
          Text('Ultima posicion', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
