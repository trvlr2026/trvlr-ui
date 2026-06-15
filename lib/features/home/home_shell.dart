import 'package:flutter/material.dart';

import '../leaderboards/leaderboard_screen.dart';
import '../map/map_screen.dart';
import '../photos/my_photos_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  static const _tabs = [
    (icon: Icons.map_rounded, label: 'Map'),
    (icon: Icons.photo_library_rounded, label: 'My Photos'),
    (icon: Icons.leaderboard_rounded, label: 'Ranks'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [MapScreen(), MyPhotosScreen(), LeaderboardScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label)).toList(),
      ),
    );
  }
}
