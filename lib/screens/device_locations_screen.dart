import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/api_client.dart';
import '../models/device.dart';
import '../models/location_point.dart';
import '../models/time_range_filter.dart';
import '../theme/app_theme.dart';
import '../utils/palette.dart';
import 'create_zone_screen.dart';

const _realtimeChoice = 'realtime';
const _staleThreshold = Duration(minutes: 2);

class DeviceLocationsScreen extends StatefulWidget {
  const DeviceLocationsScreen({super.key, required this.device});
  final Device device;

  @override
  State<DeviceLocationsScreen> createState() => _DeviceLocationsScreenState();
}

class _DeviceLocationsScreenState extends State<DeviceLocationsScreen> {
  final _apiClient = ApiClient();
  late Future<List<LocationPoint>> _locationsFuture;
  Future<double>? _distanceFuture;
  bool _showList = false;
  TimeRangeFilter _filter = const TimeRangeFilter.preset(TimeRangePreset.last6h);

  bool _isRealtime = true;
  Timer? _realtimeTimer;
  LocationPoint? _latestLocation;
  bool _realtimeLoading = true;
  String? _realtimeError;

  List<ll.LatLng>? _zonePoints;

  bool _isClusters = false;
  bool _wasRealtimeBeforeClusters = false;
  Future<List<LocationPoint>>? _clustersFuture;

  @override
  void initState() {
    super.initState();
    // Opens in realtime mode by default; _locationsFuture is only filled
    // in if the user switches to a historical range (see _openFilterMenu).
    _fetchLatest();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLatest());
    _loadZone();
  }

  Future<void> _loadZone() async {
    try {
      final points = await _apiClient.fetchGeofence(widget.device.id);
      if (!mounted) return;
      setState(() => _zonePoints = points);
    } catch (_) {
      // The zone is secondary info: if it fails, it just doesn't get drawn.
    }
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<List<LocationPoint>> _fetchWithFilter() {
    final range = _filter.resolve();
    return _apiClient.fetchLocations(widget.device.id, from: range.from, to: range.to);
  }

  Future<double> _fetchDistance() {
    final range = _filter.resolve();
    return _apiClient.fetchDeviceDistance(widget.device.id, from: range.from, to: range.to);
  }

  Future<void> _refresh() async {
    if (_isClusters) {
      setState(() {
        _clustersFuture = _apiClient.fetchLocations(widget.device.id);
      });
      await _clustersFuture;
      return;
    }
    if (_isRealtime) {
      await _fetchLatest();
      return;
    }
    setState(() {
      _locationsFuture = _fetchWithFilter();
      _distanceFuture = _fetchDistance();
    });
    await _locationsFuture;
  }

  void _toggleClusters() {
    if (_isClusters) {
      setState(() => _isClusters = false);
      // On the way out, go back to whatever mode we were in before entering
      // zones mode; otherwise _locationsFuture might not be initialized yet
      // (it's never filled in while in realtime mode).
      if (_wasRealtimeBeforeClusters) {
        _startRealtime();
      }
      return;
    }
    _wasRealtimeBeforeClusters = _isRealtime;
    _stopRealtime();
    setState(() {
      _isClusters = true;
      // Clusters are computed over the full history, ignoring the
      // current time-range filter.
      _clustersFuture = _apiClient.fetchLocations(widget.device.id);
    });
  }

  Future<void> _fetchLatest() async {
    try {
      final locations = await _apiClient.fetchLocations(widget.device.id, limit: 1);
      if (!mounted) return;
      setState(() {
        _latestLocation = locations.isNotEmpty ? locations.first : null;
        _realtimeError = null;
        _realtimeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _realtimeError = e.toString();
        _realtimeLoading = false;
      });
    }
  }

  void _startRealtime() {
    _realtimeTimer?.cancel();
    setState(() {
      _isRealtime = true;
      _realtimeLoading = true;
    });
    _fetchLatest();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLatest());
  }

  void _stopRealtime() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
    setState(() => _isRealtime = false);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final fromDate = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(hours: 6)),
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Fecha de inicio',
    );
    if (fromDate == null || !mounted) return;
    final fromTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.subtract(const Duration(hours: 6))),
      helpText: 'Hora de inicio',
    );
    if (fromTime == null || !mounted) return;

    final toDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Fecha de fin',
    );
    if (toDate == null || !mounted) return;
    final toTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: 'Hora de fin',
    );
    if (toTime == null || !mounted) return;

    final from = DateTime(fromDate.year, fromDate.month, fromDate.day, fromTime.hour, fromTime.minute);
    final to = DateTime(toDate.year, toDate.month, toDate.day, toTime.hour, toTime.minute);

    if (!from.isBefore(to)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de inicio debe ser anterior a la de fin')),
      );
      return;
    }

    _stopRealtime();
    setState(() {
      _filter = TimeRangeFilter.custom(from, to);
      _locationsFuture = _fetchWithFilter();
      _distanceFuture = _fetchDistance();
    });
  }

  Future<void> _openFilterMenu() async {
    final selection = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.podcasts,
                color: _isRealtime ? Theme.of(context).colorScheme.primary : null,
              ),
              title: const Text('Tiempo real'),
              subtitle: const Text('Actualiza cada 10 segundos'),
              selected: _isRealtime,
              onTap: () => Navigator.of(context).pop(_realtimeChoice),
            ),
            const Divider(height: 1),
            RadioGroup<TimeRangePreset>(
              groupValue: _isRealtime ? null : _filter.preset,
              onChanged: (v) => Navigator.of(context).pop(v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final preset in [
                    TimeRangePreset.last3h,
                    TimeRangePreset.last6h,
                    TimeRangePreset.last9h,
                    TimeRangePreset.last12h,
                  ])
                    RadioListTile<TimeRangePreset>(
                      title: Text(TimeRangeFilter.preset(preset).label),
                      value: preset,
                    ),
                  ListTile(
                    leading: const Icon(Icons.edit_calendar_outlined),
                    title: const Text('Personalizado...'),
                    onTap: () => Navigator.of(context).pop(TimeRangePreset.custom),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (selection == null) return;

    if (selection == _realtimeChoice) {
      _startRealtime();
      return;
    }

    if (selection == TimeRangePreset.custom) {
      await _pickCustomRange();
      return;
    }

    _stopRealtime();
    setState(() {
      _filter = TimeRangeFilter.preset(selection as TimeRangePreset);
      _locationsFuture = _fetchWithFilter();
      _distanceFuture = _fetchDistance();
    });
  }

  Future<void> _openCreateZone() async {
    ll.LatLng? initialCenter;

    if (_isRealtime && _latestLocation != null) {
      initialCenter = ll.LatLng(_latestLocation!.latitude, _latestLocation!.longitude);
    } else if (!_isRealtime) {
      try {
        final locations = await _locationsFuture;
        if (locations.isNotEmpty) {
          initialCenter = ll.LatLng(locations.first.latitude, locations.first.longitude);
        }
      } catch (_) {
        // no data, the default center will be used
      }
    }
    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateZoneScreen(device: widget.device, initialCenter: initialCenter),
      ),
    );

    if (saved == true) {
      _loadZone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _isClusters ? 'Zonas calculadas' : (_isRealtime ? 'Tiempo real' : _filter.label),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined),
            tooltip: 'Crear zona',
            onPressed: _openCreateZone,
          ),
          IconButton(
            icon: Icon(_isClusters ? Icons.blur_circular : Icons.blur_circular_outlined),
            tooltip: _isClusters ? 'Ocultar zonas calculadas' : 'Ver zonas calculadas',
            onPressed: _toggleClusters,
          ),
          if (!_isClusters) ...[
            IconButton(
              icon: Icon(_isRealtime ? Icons.podcasts : Icons.filter_alt_outlined),
              tooltip: 'Rango de tiempo',
              onPressed: _openFilterMenu,
            ),
            if (!_isRealtime)
              IconButton(
                icon: Icon(_showList ? Icons.map_outlined : Icons.list),
                tooltip: _showList ? 'Ver mapa' : 'Ver lista',
                onPressed: () => setState(() => _showList = !_showList),
              ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isClusters
            ? _buildClustersBody()
            : (_isRealtime ? _buildRealtimeBody() : _buildHistoricalBody()),
      ),
    );
  }

  Widget _buildClustersBody() {
    return FutureBuilder<List<LocationPoint>>(
      future: _clustersFuture,
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

        final withCluster = (snapshot.data ?? []).where((l) => l.cluster != null && l.cluster! >= 0).toList();
        if (withCluster.isEmpty) {
          return ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavia no hay zonas calculadas para este device.',
                ),
              ),
            ],
          );
        }

        return _ClustersMap(locations: withCluster);
      },
    );
  }

  Widget _buildRealtimeBody() {
    if (_realtimeLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _RealtimeView(
      error: _realtimeError,
      location: _latestLocation,
      zonePoints: _zonePoints,
    );
  }

  Widget _buildHistoricalBody() {
    return FutureBuilder<List<LocationPoint>>(
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
        if (_showList) {
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
          return _LocationsList(locations: locations);
        }

        return _RouteMap(
          locations: locations,
          zonePoints: _zonePoints,
          distanceFuture: _distanceFuture,
        );
      },
    );
  }
}

class _RealtimeView extends StatelessWidget {
  const _RealtimeView({required this.error, required this.location, this.zonePoints});
  final String? error;
  final LocationPoint? location;
  final List<ll.LatLng>? zonePoints;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      );
    }

    if (location == null) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: _WarningBanner(
              message: 'No hay ninguna ubicacion en tiempo real disponible para este device.',
            ),
          ),
        ],
      );
    }

    final recordedAt = location!.recordedAt;
    final isStale = recordedAt == null || DateTime.now().difference(recordedAt) > _staleThreshold;
    final point = ll.LatLng(location!.latitude, location!.longitude);

    return Column(
      children: [
        if (isStale)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _WarningBanner(
              message: recordedAt == null
                  ? 'La ultima ubicacion no tiene fecha registrada.'
                  : 'La ultima ubicacion es de hace ${_formatAge(recordedAt)}. Puede no ser en tiempo real.',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppColors.cyan, size: 10),
                const SizedBox(width: 8),
                Text('En vivo · actualizado hace ${_formatAge(recordedAt)}'),
              ],
            ),
          ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(initialCenter: point, initialZoom: 16),
            children: [
              ColorFiltered(
                colorFilter: darkTileColorFilter,
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.the_horse_tracker_app',
                ),
              ),
              if (zonePoints != null && zonePoints!.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: zonePoints!,
                      color: AppColors.olive.withValues(alpha: 0.15),
                      borderColor: AppColors.olive,
                      borderStrokeWidth: 3,
                      pattern: StrokePattern.dashed(segments: const [8, 6]),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_on,
                      color: isStale ? AppColors.textFaint : AppColors.cyan,
                      size: 40,
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
      ],
    );
  }

  String _formatAge(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds} s';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
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

// The backend returns locations from most recent to oldest; to draw the
// route in chronological order they need to be reversed.
class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.locations, this.zonePoints, this.distanceFuture});
  final List<LocationPoint> locations;
  final List<ll.LatLng>? zonePoints;
  final Future<double>? distanceFuture;

  // Roughly centers the whole country when there's no location (or zone)
  // data to fit the camera to.
  static const _spainCenter = ll.LatLng(40.4168, -3.7038);
  static const _spainZoom = 5.5;

  List<LocationPoint> get _chronological => locations.reversed.toList();

  Color _colorForIndex(int index, int count) {
    if (count <= 1) return AppColors.amber;
    final t = index / (count - 1);
    return Color.lerp(AppColors.textFaint, AppColors.amber, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final points = _chronological;
    final latLngPoints = points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
    final lastIndex = points.length - 1;
    final hasZone = zonePoints != null && zonePoints!.length >= 3;

    final boundsPoints = [...latLngPoints, if (hasZone) ...zonePoints!];

    // CameraFit.bounds computes an infinite zoom (and throws) when the
    // bounds have zero area, e.g. every point sits at the exact same
    // coordinate (a stationary device). Treat that the same as a single
    // point instead of fitting to a degenerate box.
    final bounds = boundsPoints.length > 1 ? LatLngBounds.fromPoints(boundsPoints) : null;
    final hasSpread = bounds != null && (bounds.north != bounds.south || bounds.east != bounds.west);

    final MapOptions mapOptions;
    if (hasSpread) {
      mapOptions = MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: 18,
        ),
      );
    } else if (latLngPoints.isNotEmpty) {
      mapOptions = MapOptions(initialCenter: latLngPoints.first, initialZoom: 15);
    } else {
      mapOptions = const MapOptions(initialCenter: _spainCenter, initialZoom: _spainZoom);
    }

    return Stack(
      children: [
        FlutterMap(
          // MapOptions' initialCenter/initialCameraFit are only applied the
          // first time the underlying MapController is created; without a
          // key that changes with the data, selecting a new date range
          // rebuilds this widget but the camera stays wherever it was.
          key: ValueKey(locations),
          options: mapOptions,
          children: [
            ColorFiltered(
              colorFilter: darkTileColorFilter,
              child: TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.the_horse_tracker_app',
              ),
            ),
            if (hasZone)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: zonePoints!,
                    color: AppColors.olive.withValues(alpha: 0.15),
                    borderColor: AppColors.olive,
                    borderStrokeWidth: 3,
                    pattern: StrokePattern.dashed(segments: const [8, 6]),
                  ),
                ],
              ),
            if (latLngPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(points: latLngPoints, strokeWidth: 4, color: AppColors.amber),
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
        if (points.isEmpty)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _WarningBanner(
              message: 'No hay localizaciones registradas para este device en el rango seleccionado.',
            ),
          )
        else ...[
          Positioned(
            left: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: _Legend(hasZone: hasZone),
          ),
          if (distanceFuture != null)
            Positioned(
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: _DistanceLegend(distanceFuture: distanceFuture!),
            ),
        ],
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
      return const Icon(Icons.flag, color: AppColors.textDim, size: 32);
    }
    if (isLast) {
      return const Icon(Icons.location_on, color: AppColors.cyan, size: 36);
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.text, width: 1.5),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hasZone});
  final bool hasZone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag, color: AppColors.textDim, size: 16),
          const SizedBox(width: 4),
          const Text('Inicio', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          const Icon(Icons.location_on, color: AppColors.cyan, size: 16),
          const SizedBox(width: 4),
          const Text('Ultima posicion', style: TextStyle(fontSize: 12)),
          if (hasZone) ...[
            const SizedBox(width: 12),
            const Icon(Icons.pentagon_outlined, color: AppColors.olive, size: 16),
            const SizedBox(width: 4),
            const Text('Zona', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _DistanceLegend extends StatelessWidget {
  const _DistanceLegend({required this.distanceFuture});
  final Future<double> distanceFuture;

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: FutureBuilder<double>(
        future: distanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snapshot.hasError) {
            return const Text('Distancia: --', style: TextStyle(fontSize: 12));
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.straighten, color: AppColors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                'Distancia recorrida: ${_formatDistance(snapshot.data!)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClustersMap extends StatelessWidget {
  const _ClustersMap({required this.locations});
  final List<LocationPoint> locations;

  @override
  Widget build(BuildContext context) {
    final latLngPoints = locations.map((l) => ll.LatLng(l.latitude, l.longitude)).toList();
    final clusterIds = locations.map((l) => l.cluster!).toSet().toList()..sort();

    // See _RouteMap for why zero-area bounds (all points identical) need
    // to be treated as a single point instead of passed to CameraFit.bounds.
    final bounds = latLngPoints.length > 1 ? LatLngBounds.fromPoints(latLngPoints) : null;
    final hasSpread = bounds != null && (bounds.north != bounds.south || bounds.east != bounds.west);

    final mapOptions = hasSpread
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(48),
              maxZoom: 18,
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
            CircleLayer(
              circles: [
                for (var i = 0; i < locations.length; i++)
                  CircleMarker(
                    point: latLngPoints[i],
                    radius: 10,
                    useRadiusInMeter: true,
                    color: colorForIndex(locations[i].cluster!).withValues(alpha: 0.35),
                    borderStrokeWidth: 2,
                    borderColor: colorForIndex(locations[i].cluster!),
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
        Positioned(
          left: 12,
          bottom: MediaQuery.paddingOf(context).bottom + 12,
          right: 12,
          child: _ClustersLegend(clusterIds: clusterIds),
        ),
      ],
    );
  }
}

class _ClustersLegend extends StatelessWidget {
  const _ClustersLegend({required this.clusterIds});
  final List<int> clusterIds;

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
          for (final cluster in clusterIds)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorForIndex(cluster),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('Zona $cluster', style: const TextStyle(fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}
