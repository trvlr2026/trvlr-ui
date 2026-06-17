import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/place.dart';
import '../../providers/providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  LatLng? _userLocation;
  var _checkingIn = false;
  bool _mapReady = false;

  List<Place> _places = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  StreamSubscription<MapEvent>? _mapEventSub;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Called by MapOptions.onMapReady — safe to use MapController from here on.
  void _onMapReady() {
    _mapReady = true;
    // ignore: avoid_print
    print('[Map] onMapReady fired');
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
    }
    _loadPlaces();
    _mapEventSub = _mapController.mapEventStream.listen((event) {
      // Log every event type so we can see what flutter_map 7 actually emits.
      // ignore: avoid_print
      print('[Map] event: ${event.runtimeType}');
      if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
        _scheduleLoad();
      }
    });
  }

  Future<void> _loadUserLocation() async {
    final pos = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted || pos == null) return;
    final loc = LatLng(pos.latitude, pos.longitude);
    setState(() => _userLocation = loc);
    // Only call move if the map is already ready; otherwise _onMapReady
    // will move to _userLocation when it fires.
    if (_mapReady) {
      _mapController.move(loc, 15);
    }
  }

  void _scheduleLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), _loadPlaces);
  }

  Future<void> _loadPlaces() async {
    if (!mounted || !_mapReady) return;

    final center = _mapController.camera.center;
    final radius = _visibleRadiusMeters();

    setState(() => _isLoading = true);
    // ignore: avoid_print
    print('[Map] loading places  center=(${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)})  radius=${radius.toStringAsFixed(0)}m');
    try {
      final places = await ref.read(repositoryProvider).getAllPlaces(
            lat: center.latitude,
            lon: center.longitude,
            radiusM: radius,
          );
      // ignore: avoid_print
      print('[Map] loaded ${places.length} places');
      if (mounted) setState(() => _places = places);
    } catch (_) {
      // keep existing pins on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Computes the distance in metres from the map centre to the NE corner of
  /// the visible bounds — used directly as the /nearby/ radius.
  double _visibleRadiusMeters() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      final center = _mapController.camera.center;
      final dist = const Distance().as(
        LengthUnit.Meter,
        LatLng(center.latitude, center.longitude),
        LatLng(bounds.northEast.latitude, bounds.northEast.longitude),
      );
      return dist.clamp(100, 500000).toDouble();
    } catch (_) {
      return 5000;
    }
  }

  // ── Clustering ────────────────────────────────────────────────────────────

  /// Pixel radius within which pins are merged into a cluster.
  /// Shrinks as the user zooms in so individual pins emerge naturally.
  double get _clusterRadiusPx {
    final zoom = _mapController.camera.zoom;
    if (zoom >= 17) return 0;   // fully zoomed in → never cluster
    if (zoom >= 15) return 25;
    if (zoom >= 13) return 40;
    return 55;
  }

  List<_Cluster> _clusterPlaces(List<Place> places) {
    final radiusPx = _clusterRadiusPx;
    final assigned = List.filled(places.length, false);
    final clusters = <_Cluster>[];

    for (var i = 0; i < places.length; i++) {
      if (assigned[i]) continue;

      final ptI = _mapController.camera.latLngToScreenPoint(
        LatLng(places[i].latitude, places[i].longitude),
      );
      final group = [places[i]];
      assigned[i] = true;

      if (radiusPx > 0) {
        for (var j = i + 1; j < places.length; j++) {
          if (assigned[j]) continue;
          final ptJ = _mapController.camera.latLngToScreenPoint(
            LatLng(places[j].latitude, places[j].longitude),
          );
          final dx = ptI.x - ptJ.x;
          final dy = ptI.y - ptJ.y;
          if (sqrt(dx * dx + dy * dy) < radiusPx) {
            group.add(places[j]);
            assigned[j] = true;
          }
        }
      }

      final lat = group.map((p) => p.latitude).reduce((a, b) => a + b) / group.length;
      final lon = group.map((p) => p.longitude).reduce((a, b) => a + b) / group.length;
      clusters.add(_Cluster(places: group, center: LatLng(lat, lon)));
    }

    return clusters;
  }

  // ── Marker building ───────────────────────────────────────────────────────

  List<Marker> _buildMarkers(Set<String> visited) {
    // Camera is not accessible before onMapReady — skip clustering until ready.
    if (!_mapReady || _places.isEmpty) return [];
    final clusters = _clusterPlaces(_places);
    return clusters.map((c) {
      return c.isSingle
          ? _placeMarker(c.places.first, visited.contains(c.places.first.id))
          : _clusterMarker(c);
    }).toList();
  }

  Marker _clusterMarker(_Cluster cluster) {
    final count = cluster.places.length;
    final color = count < 5
        ? AppColors.primary
        : count < 15
            ? AppColors.accent
            : const Color(0xFFEF4444);

    return Marker(
      point: cluster.center,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () {
          if (_mapReady) {
            _mapController.move(cluster.center, _mapController.camera.zoom + 2);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _placeMarker(Place place, bool visited) {
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showPlaceSheet(place, visited),
        child: Icon(
          Icons.place,
          color: visited ? AppColors.visited : AppColors.unvisited,
          size: 32,
        ),
      ),
    );
  }

  // ── Check-in ──────────────────────────────────────────────────────────────

  Future<void> _checkIn() async {
    setState(() => _checkingIn = true);
    try {
      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        _showResult(false, 'Location unavailable. Enable location permissions.');
        return;
      }
      final result = await ref.read(repositoryProvider).checkIn(pos.latitude, pos.longitude);
      ref.invalidate(visitsProvider);
      ref.invalidate(visitedPlaceIdsProvider);
      ref.invalidate(userStatsProvider);
      if (!mounted) return;
      _showResult(result.success, result.message, points: result.pointsEarned);
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  void _showResult(bool success, String message, {int points = 0}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline,
              size: 56,
              color: success ? AppColors.visited : AppColors.accent,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
            if (points > 0) ...[
              const SizedBox(height: 8),
              Text('+$points points',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ],
        ),
      ),
    );
  }

  void _showPlaceSheet(Place place, bool visited) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (place.district.isNotEmpty)
              Text([place.district, place.state].where((s) => s.isNotEmpty).join(', ')),
            const SizedBox(height: 8),
            Text('${place.pointsValue} points · ${place.radiusM}m radius'),
            if (place.category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(place.category, style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 8),
            Chip(
              label: Text(visited ? 'Visited' : 'Not visited yet'),
              backgroundColor: visited ? AppColors.visited.withValues(alpha: 0.15) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visitedAsync = ref.watch(visitedPlaceIdsProvider);
    final visited = visitedAsync.value ?? {};
    final center = _userLocation ?? const LatLng(20.5937, 78.9629);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 18,
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trvlr.trvlr_ui',
              ),
              if (_userLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _userLocation!,
                    width: 24,
                    height: 24,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 24),
                  ),
                ]),
              MarkerLayer(markers: _buildMarkers(visited)),
            ],
          ),

          // Loading indicator
          if (_isLoading)
            const Positioned(
              top: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkingIn ? null : _checkIn,
        icon: _checkingIn
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_location_alt),
        label: const Text('Check in'),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _Cluster {
  const _Cluster({required this.places, required this.center});

  final List<Place> places;
  final LatLng center;

  bool get isSingle => places.length == 1;
}
