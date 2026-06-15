import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  var _page = 0;
  var _locationGranted = false;
  var _photosGranted = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    final granted = await ref.read(permissionServiceProvider).requestLocation();
    setState(() => _locationGranted = granted);
  }

  Future<void> _requestPhotos() async {
    final state = await ref.read(permissionServiceProvider).requestPhotos();
    setState(() => _photosGranted = state.hasAccess);
  }

  Future<void> _finish() async {
    final repo = ref.read(repositoryProvider);
    await repo.setOnboardingComplete(true);
    if (!mounted) return;
    if (_photosGranted) {
      context.go('/photo-import');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get started')),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _OnboardPage(
                  icon: Icons.explore_rounded,
                  title: 'Explore India',
                  body: 'Visit curated landmarks and earn points. Climb district, state, and national leaderboards.',
                ),
                _OnboardPage(
                  icon: Icons.my_location_rounded,
                  title: 'Location access',
                  body: 'Allow location so Trvlr can detect when you arrive at a place and award points automatically.',
                  action: FilledButton.icon(
                    onPressed: _requestLocation,
                    icon: Icon(_locationGranted ? Icons.check_circle : Icons.location_on),
                    label: Text(_locationGranted ? 'Location enabled' : 'Enable location'),
                  ),
                ),
                _OnboardPage(
                  icon: Icons.photo_library_rounded,
                  title: 'Import past travels',
                  body: 'We only read GPS metadata from your photos — photos never leave your device. This pre-fills places you have already visited.',
                  action: FilledButton.icon(
                    onPressed: _requestPhotos,
                    icon: Icon(_photosGranted ? Icons.check_circle : Icons.photo),
                    label: Text(_photosGranted ? 'Photos access granted' : 'Allow photo access'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Row(
                  children: List.generate(3, (i) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _page == i ? const Color(0xFF0D9488) : Colors.grey.shade300,
                    ),
                  )),
                ),
                const Spacer(),
                if (_page < 2)
                  TextButton(
                    onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: const Text('Next'),
                  )
                else
                  FilledButton(onPressed: _finish, child: const Text('Continue')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: const Color(0xFF0D9488)),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), height: 1.4)),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
