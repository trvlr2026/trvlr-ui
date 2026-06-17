import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../leaderboards/leaderboard_screen.dart';
import '../map/map_screen.dart';
import '../photos/my_photos_screen.dart';
import '../profile/profile_screen.dart';
import '../spots/spots_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  var _index = 0;

  static const _tabs = [
    (icon: Icons.map_rounded, label: 'Map'),
    (icon: Icons.photo_library_rounded, label: 'My Photos'),
    (icon: Icons.explore_rounded, label: 'Spots'),
    (icon: Icons.leaderboard_rounded, label: 'Ranks'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final backendStatus = ref.watch(backendStatusProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [MapScreen(), MyPhotosScreen(), SpotsScreen(), LeaderboardScreen(), ProfileScreen()],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: _BackendStatusChip(status: backendStatus),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label)).toList(),
      ),
    );
  }
}

class _BackendStatusChip extends StatelessWidget {
  const _BackendStatusChip({required this.status});
  final AsyncValue<bool> status;

  @override
  Widget build(BuildContext context) {
    final isOnline = status.valueOrNull ?? false;
    final isLoading = status is AsyncLoading;

    final color = isOnline ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);
    final label = isLoading ? 'Checking...' : (isOnline ? 'Online' : 'Offline');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isOnline
                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1)]
                    : null,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
