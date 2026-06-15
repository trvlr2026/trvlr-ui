import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/geo_tagged_photo.dart';
import '../../providers/providers.dart';

class MyPhotosScreen extends ConsumerWidget {
  const MyPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanAsync = ref.watch(myPhotosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan gallery',
            onPressed: () => ref.invalidate(myPhotosProvider),
          ),
        ],
      ),
      body: scanAsync.when(
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatsBanner(result: result),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: result.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _PhotoRow(photo: result.photos[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({required this.result});

  final GalleryScanResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: _StatItem(label: 'Total photos', value: '${result.totalPhotos}')),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            Expanded(child: _StatItem(label: 'With location', value: '${result.geotaggedCount}')),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            Expanded(child: _StatItem(label: 'Matched places', value: '${result.matchedPlacesCount}')),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                    Text('${photo.district}, ${photo.state}', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                  if (photo.coordinatesLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(photo.coordinatesLabel!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  if (!hasLocation) ...[
                    const SizedBox(height: 4),
                    const Text('No GPS in photo metadata', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ] else if (!hasPlace) ...[
                    const SizedBox(height: 4),
                    const Text('No matching place', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  if (dateLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PhotoThumbnail(assetId: photo.assetId),
          ],
        ),
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
