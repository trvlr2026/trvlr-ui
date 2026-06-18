import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/photo_id.dart';
import '../../data/models/api_visit.dart';
import '../../data/models/bulk_checkin.dart';
import '../../data/models/geo_tagged_photo.dart';
import '../../providers/providers.dart';

class MyPhotosScreen extends ConsumerStatefulWidget {
  const MyPhotosScreen({super.key});

  @override
  ConsumerState<MyPhotosScreen> createState() => _MyPhotosScreenState();
}

class _MyPhotosScreenState extends ConsumerState<MyPhotosScreen> {
  // null = idle; non-null = check-in in progress
  ({int done, int total})? _checkInProgress;

  static const _checkInBatchSize = 100;

  bool get _checkingIn => _checkInProgress != null;

  Future<void> _bulkCheckIn(GalleryScanResult result) async {
    final coords = result.photos
        .where((p) => p.hasLocation)
        .map((p) => (
              lat: p.latitude!,
              lon: p.longitude!,
              photoId: generatePhotoId(p.latitude!, p.longitude!, p.takenAt),
            ))
        .toList();

    final totalPhotos = result.totalPhotos;
    final missingCoords = totalPhotos - result.geotaggedCount;
    final total = coords.length;

    setState(() => _checkInProgress = (done: 0, total: total));

    try {
      final allScores = <BulkCheckInScore>[];

      // Process in batches of 100
      for (var start = 0; start < total; start += _checkInBatchSize) {
        final end = (start + _checkInBatchSize).clamp(0, total);
        final batch = coords.sublist(start, end);

        final batchResult = await ref.read(repositoryProvider).bulkCheckIn(batch);
        allScores.addAll(batchResult.scores);

        if (!mounted) return;
        setState(() => _checkInProgress = (done: end, total: total));
      }

      if (!mounted) return;

      // Refresh stats + visits + categorized photos after earning new points
      ref.invalidate(visitsProvider);
      ref.invalidate(userStatsProvider);
      ref.invalidate(allVisitedPlacesProvider);

      _showResultSheet(
        totalPhotos: totalPhotos,
        missingCoords: missingCoords,
        considered: total,
        checkInResult: BulkCheckInResult(scores: allScores),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _checkInProgress = null);
    }
  }

  void _showResultSheet({
    required int totalPhotos,
    required int missingCoords,
    required int considered,
    required BulkCheckInResult checkInResult,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _BulkCheckInResultSheet(
        totalPhotos: totalPhotos,
        missingCoords: missingCoords,
        considered: considered,
        checkInResult: checkInResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanAsync = ref.watch(myPhotosProvider);
    final isOnline = ref.watch(backendStatusProvider).valueOrNull?.isOnline ?? false;
    final visitedPlacesAsync = ref.watch(allVisitedPlacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan gallery',
            onPressed: () {
              ref.invalidate(myPhotosProvider);
              ref.invalidate(allVisitedPlacesProvider);
            },
          ),
        ],
      ),
          floatingActionButton: (isOnline && scanAsync.value != null && !scanAsync.value!.permissionDenied && scanAsync.value!.geotaggedCount > 0)
          ? FloatingActionButton.extended(
              onPressed: _checkingIn ? null : () => _bulkCheckIn(scanAsync.value!),
              icon: _checkingIn
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.where_to_vote_rounded),
              label: Text(_checkingIn ? 'Checking in...' : 'Bulk check-in'),
            )
          : null,
      body: Stack(
        children: [
          scanAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text('Could not load photos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(myPhotosProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (result) {
          if (result.permissionDenied) {
            return _PermissionDeniedView(
              onRetry: () => ref.invalidate(myPhotosProvider),
            );
          }
          if (result.photos.isEmpty) {
            return _EmptyView(totalPhotos: result.totalPhotos);
          }

          final visitedPlaces = visitedPlacesAsync.valueOrNull ?? [];
          final sections = _categorize(result, visitedPlaces, isOnline);

          // Build flat list: section headers + photo items interleaved
          final items = <Object>[];
          if (sections.visited.isNotEmpty) {
            items.add(_SectionMeta(
              title: 'Visited',
              icon: Icons.check_circle_rounded,
              color: AppColors.primary,
              count: sections.visited.length,
            ));
            items.addAll(sections.visited);
          }
          if (sections.unknown.isNotEmpty) {
            items.add(_SectionMeta(
              title: 'Unknown',
              icon: Icons.help_outline_rounded,
              color: Colors.amber.shade700,
              count: sections.unknown.length,
            ));
            items.addAll(sections.unknown);
          }
          if (sections.noGps.isNotEmpty) {
            items.add(_SectionMeta(
              title: 'No GPS',
              icon: Icons.location_off_rounded,
              color: AppColors.textSecondary,
              count: sections.noGps.length,
            ));
            items.addAll(sections.noGps);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatsBanner(result: result, isOnline: isOnline, visitedCount: sections.visited.length),
              if (isOnline && visitedPlacesAsync.isLoading)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is _SectionMeta) {
                      return _SectionHeader(meta: item);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PhotoRow(photo: item as GeoTaggedPhoto),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
          // ── Check-in progress banner (floats above content) ──────────────
          if (_checkInProgress != null)
            _CheckInProgressBanner(progress: _checkInProgress!),
        ],
      ),
    );
  }

  ({List<GeoTaggedPhoto> visited, List<GeoTaggedPhoto> unknown, List<GeoTaggedPhoto> noGps}) _categorize(
    GalleryScanResult result,
    List<ApiVisit> visitedEntries,
    bool isOnline,
  ) {
    final noGps = <GeoTaggedPhoto>[];
    final visited = <GeoTaggedPhoto>[];
    final unknown = <GeoTaggedPhoto>[];

    // Map photo_id → visit so Visited photos can be enriched with location name
    final visitMap = isOnline
        ? {for (final v in visitedEntries) v.photoId: v}
        : const <String, ApiVisit>{};

    for (final photo in result.photos) {
      if (!photo.hasLocation) {
        noGps.add(photo);
        continue;
      }

      if (isOnline && visitMap.isNotEmpty) {
        final id = generatePhotoId(photo.latitude!, photo.longitude!, photo.takenAt);
        final visit = visitMap[id];
        if (visit != null) {
          visited.add(GeoTaggedPhoto(
            assetId: photo.assetId,
            latitude: photo.latitude,
            longitude: photo.longitude,
            takenAt: photo.takenAt,
            placeName: visit.location.placeName,
            district: visit.location.district,
            state: photo.state,
            earnedScore: visit.score,
            locationType: visit.location.locationType,
          ));
        } else {
          unknown.add(photo);
        }
      } else {
        unknown.add(photo);
      }
    }

    return (visited: visited, unknown: unknown, noGps: noGps);
  }
}

// ── Result bottom sheet ──────────────────────────────────────────────────────

class _BulkCheckInResultSheet extends StatelessWidget {
  const _BulkCheckInResultSheet({
    required this.totalPhotos,
    required this.missingCoords,
    required this.considered,
    required this.checkInResult,
  });

  final int totalPhotos;
  final int missingCoords;
  final int considered;
  final BulkCheckInResult checkInResult;

  @override
  Widget build(BuildContext context) {
    final earned = checkInResult.totalEarned;
    final newPlaces = checkInResult.newPlacesCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(
              earned > 0 ? Icons.celebration_rounded : Icons.where_to_vote_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              earned > 0 ? 'Check-in complete!' : 'Nothing new this time',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          _ResultRow(
            icon: Icons.photo_library_outlined,
            label: 'Total photos scanned',
            value: '$totalPhotos',
          ),
          _ResultRow(
            icon: Icons.location_off_outlined,
            label: 'Missing GPS (skipped)',
            value: '$missingCoords',
            valueColor: missingCoords > 0 ? AppColors.textSecondary : null,
          ),
          _ResultRow(
            icon: Icons.my_location_rounded,
            label: 'Locations sent to backend',
            value: '$considered',
          ),
          const Divider(height: 28),
          _ResultRow(
            icon: Icons.place_rounded,
            label: 'New places discovered',
            value: '$newPlaces',
            valueColor: newPlaces > 0 ? AppColors.primary : null,
          ),
          _ResultRow(
            icon: Icons.star_rounded,
            label: 'Points earned',
            value: '+$earned',
            valueColor: earned > 0 ? AppColors.primary : AppColors.textSecondary,
            bold: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 18 : 14,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section metadata + header ─────────────────────────────────────────────────

class _SectionMeta {
  const _SectionMeta({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int count;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.meta});

  final _SectionMeta meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: meta.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(meta.icon, size: 18, color: meta.color),
          const SizedBox(width: 6),
          Text(
            meta.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: meta.color,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: meta.color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
          child: Text(
              '${meta.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: meta.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.result,
    required this.isOnline,
    required this.visitedCount,
  });

  final GalleryScanResult result;
  final bool isOnline;
  final int visitedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: _StatItem(label: 'Total', value: '${result.totalPhotos}')),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            Expanded(child: _StatItem(label: 'With GPS', value: '${result.geotaggedCount}')),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            if (isOnline)
              Expanded(
                child: _StatItem(
                  label: 'Visited',
                  value: '$visitedCount',
                  valueColor: AppColors.primary,
                ),
              )
            else
              Expanded(
                child: _StatItem(
                  label: 'Matched',
                  value: '${result.matchedPlacesCount}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LoadingView extends ConsumerWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(myPhotosScanProgressProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              progress == null ? 'Scanning your gallery...' : 'Scanning photos... ${progress.$1} / ${progress.$2}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Reading photos and GPS metadata (this may take a moment)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends ConsumerStatefulWidget {
  const _PermissionDeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  ConsumerState<_PermissionDeniedView> createState() => _PermissionDeniedViewState();
}

class _PermissionDeniedViewState extends ConsumerState<_PermissionDeniedView> {
  var _requesting = false;
  var _showSettings = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionState();
  }

  Future<void> _checkPermissionState() async {
    final state = await PhotoManager.getPermissionState(requestOption: photoPermissionRequest);
    if (mounted) setState(() => _showSettings = state.needsSettings);
  }

  Future<void> _grantAccess() async {
    setState(() => _requesting = true);
    try {
      final state = await ref.read(permissionServiceProvider).requestPhotos();
      if (!mounted) return;
      if (state.hasAccess) {
        widget.onRetry();
        return;
      }
      setState(() => _showSettings = state.needsSettings);
      if (state.needsSettings && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied. Open Settings to allow photo access.')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _openSettings() async {
    await ref.read(permissionServiceProvider).openSettings();
    if (!mounted) return;
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Photo access needed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Allow photo library access so Trvlr can read your gallery and location metadata from photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _requesting ? null : _grantAccess,
              icon: _requesting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.photo_library),
              label: Text(_requesting ? 'Requesting...' : 'Grant access'),
            ),
            if (_showSettings) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.totalPhotos});

  final int totalPhotos;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No photos found', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              totalPhotos == 0
                  ? 'Your gallery appears empty, or photos could not be read.'
                  : 'Found $totalPhotos photos but none could be loaded.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.photo});

  final GeoTaggedPhoto photo;

  @override
  Widget build(BuildContext context) {
    final hasPlace = photo.hasMatchedPlace;
    final hasLocation = photo.hasLocation;
    final dateLabel = photo.takenAt != null ? DateFormat.yMMMd().format(photo.takenAt!) : null;
    final typeTags = _locationTags(photo.locationType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.displayTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasPlace
                              ? AppColors.primaryDark
                              : hasLocation
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                        ),
                  ),
                  if (hasPlace && photo.district != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      photo.state != null
                          ? '${photo.district}, ${photo.state}'
                          : '${photo.district}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  if (!hasLocation) ...[
                    const SizedBox(height: 4),
                    const Text('No GPS in photo metadata',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ] else if (!hasPlace) ...[
                    const SizedBox(height: 4),
                    const Text('No matching place',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  if (dateLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(dateLabel,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  if (typeTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: typeTags.map((t) => _Tag(label: t)).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // thumbnail + score stacked, 88 px wide
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PhotoThumbnail(assetId: photo.assetId),
                if (photo.earnedScore != null) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 88,
                    child: _Tag(
                      label: '+${photo.earnedScore} pts',
                      color: AppColors.primary,
                      centered: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "tourism:hostel" → ["tourism", "hostel"],  "park" → ["park"]
  static List<String> _locationTags(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(':').map((s) => s.replaceAll('_', ' ')).toList();
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color = AppColors.textSecondary, this.centered = false});

  final String label;
  final Color color;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: centered ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        height: 88,
        child: FutureBuilder<AssetEntity?>(
          future: AssetEntity.fromId(assetId),
          builder: (context, assetSnapshot) {
            final asset = assetSnapshot.data;
            if (asset == null) {
              return ColoredBox(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              );
            }
            return FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
              builder: (context, thumbSnapshot) {
                final data = thumbSnapshot.data;
                if (data == null) {
                  return const ColoredBox(
                    color: Color(0xFFE2E8F0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                return Image.memory(data, fit: BoxFit.cover);
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Check-in progress banner ─────────────────────────────────────────────────

class _CheckInProgressBanner extends StatelessWidget {
  const _CheckInProgressBanner({required this.progress});

  final ({int done, int total}) progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.total > 0 ? progress.done / progress.total : 0.0;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: fraction, minHeight: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Checking in… ${progress.done} / ${progress.total} photos',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
