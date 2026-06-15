import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../data/models/place.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  LatLng? _userLocation;
  var _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final pos = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted || pos == null) return;
    setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    _mapController.move(_userLocation!, 10);
  }

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
            Icon(success ? Icons.check_circle_rounded : Icons.info_outline, size: 56, color: success ? AppColors.visited : AppColors.accent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
            if (points > 0) ...[
              const SizedBox(height: 8),
              Text('+$points points', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final visitedAsync = ref.watch(visitedPlaceIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (places) {
          final visited = visitedAsync.value ?? {};
          final center = _userLocation ?? LatLng(20.5937, 78.9629);
          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 5, minZoom: 4, maxZoom: 16),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trvlr.trvlr_ui',
              ),
              if (_userLocation != null)
                MarkerLayer(markers: [
                  Marker(point: _userLocation!, width: 24, height: 24, child: const Icon(Icons.my_location, color: Colors.blue, size: 24)),
                ]),
              MarkerLayer(
                markers: places.map((p) => _placeMarker(p, visited.contains(p.id))).toList(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkingIn ? null : _checkIn,
        icon: _checkingIn ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_location_alt),
        label: const Text('Check in'),
      ),
    );
  }

  Marker _placeMarker(Place place, bool visited) {
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${place.district}, ${place.state}'),
                  const SizedBox(height: 8),
                  Text('${place.pointsValue} points · ${place.radiusM}m radius'),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(visited ? 'Visited' : 'Not visited yet'),
                    backgroundColor: visited ? AppColors.visited.withValues(alpha: 0.15) : null,
                  ),
                ],
              ),
            ),
          );
        },
        child: Icon(Icons.place, color: visited ? AppColors.visited : AppColors.unvisited, size: 32),
      ),
    );
  }
}
