import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';

class PhotoImportScreen extends ConsumerStatefulWidget {
  const PhotoImportScreen({super.key});

  @override
  ConsumerState<PhotoImportScreen> createState() => _PhotoImportScreenState();
}

class _PhotoImportScreenState extends ConsumerState<PhotoImportScreen> {
  var _scanning = false;
  var _scanned = 0;
  var _total = 0;
  var _points = 0;
  var _places = 0;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);
    final scanner = ref.read(photoScannerProvider);
    final coords = await scanner.scanGallery(onProgress: (s, t) {
      if (mounted) setState(() { _scanned = s; _total = t; });
    });
    final result = await ref.read(repositoryProvider).importPhotoVisits(coords);
    ref.invalidate(visitsProvider);
    ref.invalidate(visitedPlaceIdsProvider);
    ref.invalidate(userStatsProvider);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _points = result.totalPointsEarned;
      _places = result.newVisits.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import travels')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _scanning
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('Scanning photos... $_scanned / $_total', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Reading location metadata from your gallery', textAlign: TextAlign.center),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_places > 0 ? Icons.celebration_rounded : Icons.photo_library_outlined, size: 72, color: const Color(0xFF0D9488)),
                  const SizedBox(height: 24),
                  Text(
                    _places > 0 ? 'Found $_places places!' : 'No matching places found',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _places > 0 ? 'You earned $_points points from your photo history.' : 'You can still earn points by checking in when you visit places.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(onPressed: () => context.go('/home'), child: const Text('Start exploring')),
                ],
              ),
      ),
    );
  }
}
