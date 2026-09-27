import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/api_client.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';

enum _ZoneShape { polygon, circle }

// How many vertices approximate a circle when it's sent to the backend,
// which only understands polygons (a list of lat/lng points).
const _circleApproximationSegments = 48;
const _minCircleRadiusMeters = 5.0;
const _defaultCircleRadiusMeters = 60.0;

const _distance = ll.Distance();

class CreateZoneScreen extends StatefulWidget {
  const CreateZoneScreen({super.key, required this.device, this.initialCenter});
  final Device device;
  final ll.LatLng? initialCenter;

  @override
  State<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends State<CreateZoneScreen> {
  final _apiClient = ApiClient();
  final _mapKey = GlobalKey();
  final _mapController = MapController();

  final List<ll.LatLng> _points = [];

  _ZoneShape _shape = _ZoneShape.polygon;
  ll.LatLng? _circleCenter;
  // A point that sits on the circle's edge; the radius is derived from its
  // distance to the center. Dragging it resizes the circle, wherever it goes.
  ll.LatLng? _circleEdge;

  // While a handle is being dragged, the map's own pan/zoom gestures are
  // disabled so they don't fight with the drag.
  bool _draggingHandle = false;

  bool _saving = false;
  bool _loading = true;

  double? get _circleRadiusMeters => (_circleCenter != null && _circleEdge != null)
      ? _distance.distance(_circleCenter!, _circleEdge!)
      : null;

  bool get _canSave {
    if (_shape == _ZoneShape.circle) {
      final radius = _circleRadiusMeters;
      return radius != null && radius >= _minCircleRadiusMeters;
    }
    return _points.length >= 3;
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await _apiClient.fetchGeofenceDetails(widget.device.id);
      if (!mounted) return;
      setState(() {
        if (existing != null) {
          if (existing.geometryType == 'circle') {
            final circle = _deriveCircleFromPoints(existing.points);
            if (circle != null) {
              _shape = _ZoneShape.circle;
              _circleCenter = circle.center;
              _circleEdge = circle.edge;
            }
          } else {
            _points.addAll(existing.points);
          }
        }
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

  void _onMapTap(ll.LatLng point) {
    if (_saving) return;
    if (_shape == _ZoneShape.polygon) {
      setState(() => _points.add(point));
      return;
    }
    setState(() {
      _circleCenter = point;
      _circleEdge = _distance.offset(point, _defaultCircleRadiusMeters, 90);
    });
  }

  void _undo() {
    if (_saving) return;
    if (_shape == _ZoneShape.circle) {
      if (_circleCenter == null) return;
      setState(() {
        _circleCenter = null;
        _circleEdge = null;
      });
      return;
    }
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clear() {
    if (_saving) return;
    if (_shape == _ZoneShape.circle) {
      if (_circleCenter == null) return;
      setState(() {
        _circleCenter = null;
        _circleEdge = null;
      });
      return;
    }
    if (_points.isEmpty) return;
    setState(() => _points.clear());
  }

  bool get _canUndoOrClear =>
      _shape == _ZoneShape.circle ? _circleCenter != null : _points.isNotEmpty;

  // Converts a raw global pointer position (from a Listener) into a map
  // coordinate, using the FlutterMap's own render box as the reference
  // frame that MapCamera's screen<->LatLng conversions expect.
  ll.LatLng? _globalPositionToLatLng(Offset globalPosition) {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    return _mapController.camera.screenOffsetToLatLng(local);
  }

  void _onHandleDragStart() {
    setState(() => _draggingHandle = true);
  }

  void _onHandleDragEnd() {
    if (_draggingHandle) setState(() => _draggingHandle = false);
  }

  void _onCenterHandleDrag(Offset globalPosition) {
    final newCenter = _globalPositionToLatLng(globalPosition);
    if (newCenter == null || _circleCenter == null || _circleEdge == null) return;
    // Moving the center should translate the whole circle, not resize it:
    // shift the edge point by the same delta so the radius stays constant.
    final deltaLat = newCenter.latitude - _circleCenter!.latitude;
    final deltaLng = newCenter.longitude - _circleCenter!.longitude;
    setState(() {
      _circleCenter = newCenter;
      _circleEdge = ll.LatLng(
        _circleEdge!.latitude + deltaLat,
        _circleEdge!.longitude + deltaLng,
      );
    });
  }

  void _onEdgeHandleDrag(Offset globalPosition) {
    final newEdge = _globalPositionToLatLng(globalPosition);
    if (newEdge == null) return;
    setState(() => _circleEdge = newEdge);
  }

  // The backend only stores polygons, so a circle is approximated as a
  // regular polygon with enough vertices to look smooth.
  List<ll.LatLng> _circleToPolygon(ll.LatLng center, double radiusMeters) {
    return [
      for (var i = 0; i < _circleApproximationSegments; i++)
        _distance.offset(center, radiusMeters, i * 360 / _circleApproximationSegments),
    ];
  }

  // The backend stores a circle as its polygon approximation (the actual
  // center/radius aren't persisted as separate fields), so reopening one for
  // editing means re-deriving them from those points. geometryType from the
  // server (rather than guessing from the point count/shape) is what tells
  // us it's safe to interpret them this way.
  ({ll.LatLng center, ll.LatLng edge})? _deriveCircleFromPoints(List<ll.LatLng> points) {
    if (points.length < 3) return null;

    final center = ll.LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
    );

    return (center: center, edge: points.first);
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final List<ll.LatLng> pointsToSave;
    if (_shape == _ZoneShape.circle) {
      pointsToSave = _circleToPolygon(_circleCenter!, _circleRadiusMeters!);
    } else {
      pointsToSave = _points;
    }

    setState(() => _saving = true);
    try {
      await _apiClient.saveGeofence(
        widget.device.id,
        pointsToSave,
        geometryType: _shape == _ZoneShape.circle ? 'circle' : 'polygon',
      );
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

  Widget _dragHandle({required Color color, required IconData icon}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.text, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: AppColors.onAmber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter ??
        _circleCenter ??
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
            onPressed: (!_canSave || _saving) ? null : _save,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<_ZoneShape>(
                        segments: const [
                          ButtonSegment(
                            value: _ZoneShape.polygon,
                            label: Text('Polígono'),
                            icon: Icon(Icons.pentagon_outlined),
                          ),
                          ButtonSegment(
                            value: _ZoneShape.circle,
                            label: Text('Círculo'),
                            icon: Icon(Icons.circle_outlined),
                          ),
                        ],
                        selected: {_shape},
                        onSelectionChanged: _saving
                            ? null
                            : (selection) => setState(() => _shape = selection.first),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _shape == _ZoneShape.polygon
                            ? 'Toca el mapa para marcar los vertices del perimetro (minimo 3).'
                            : _circleCenter == null
                                ? 'Toca el mapa para colocar el centro del circulo.'
                                : 'Arrastra el punto central para mover el circulo, o el tirador del borde para cambiar el radio.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    key: _mapKey,
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                      interactionOptions: InteractionOptions(
                        flags: _draggingHandle ? InteractiveFlag.none : InteractiveFlag.all,
                      ),
                      onTap: (_, point) => _onMapTap(point),
                    ),
                    children: [
                      ColorFiltered(
                        colorFilter: darkTileColorFilter,
                        child: TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.the_horse_tracker_app',
                        ),
                      ),
                      if (_shape == _ZoneShape.polygon) ...[
                        if (_points.length >= 3)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: _points,
                                color: AppColors.olive.withValues(alpha: 0.2),
                                borderColor: AppColors.olive,
                                borderStrokeWidth: 3,
                                pattern: StrokePattern.dashed(segments: const [8, 6]),
                              ),
                            ],
                          )
                        else if (_points.length == 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(points: _points, strokeWidth: 3, color: AppColors.olive),
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
                                    color: AppColors.olive,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.text, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: AppColors.onAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ] else ...[
                        if (_circleCenter != null && _circleRadiusMeters != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _circleCenter!,
                                radius: _circleRadiusMeters!,
                                useRadiusInMeter: true,
                                color: AppColors.olive.withValues(alpha: 0.2),
                                borderColor: AppColors.olive,
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (_circleCenter != null)
                              Marker(
                                point: _circleCenter!,
                                width: 32,
                                height: 32,
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (_) => _onHandleDragStart(),
                                  onPointerMove: (event) => _onCenterHandleDrag(event.position),
                                  onPointerUp: (_) => _onHandleDragEnd(),
                                  onPointerCancel: (_) => _onHandleDragEnd(),
                                  child: _dragHandle(color: AppColors.olive, icon: Icons.open_with),
                                ),
                              ),
                            if (_circleEdge != null)
                              Marker(
                                point: _circleEdge!,
                                width: 32,
                                height: 32,
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (_) => _onHandleDragStart(),
                                  onPointerMove: (event) => _onEdgeHandleDrag(event.position),
                                  onPointerUp: (_) => _onHandleDragEnd(),
                                  onPointerCancel: (_) => _onHandleDragEnd(),
                                  child: _dragHandle(color: AppColors.amber, icon: Icons.sync_alt),
                                ),
                              ),
                          ],
                        ),
                      ],
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_shape == _ZoneShape.circle && _circleRadiusMeters != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Radio: ${_circleRadiusMeters!.round()} m',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
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
                            onPressed: (!_canUndoOrClear || _saving) ? null : _undo,
                            icon: const Icon(Icons.undo),
                            label: const Text('Deshacer'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (!_canUndoOrClear || _saving) ? null : _clear,
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
