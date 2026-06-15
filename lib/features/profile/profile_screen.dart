import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final visitsAsync = ref.watch(visitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(repositoryProvider).logout();
              ref.invalidate(currentUserProvider);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('Not signed in'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF0D9488),
                        child: Text(
                          _initialFor(user.displayName, user.email),
                          style: const TextStyle(fontSize: 28, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(user.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${user.homeDistrict}, ${user.homeState}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              statsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(
                  children: [
                    Expanded(child: _StatCard(label: 'Total points', value: '${stats.totalPoints}')),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Places visited', value: '${stats.placesVisited}')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Points by state', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => stats.pointsByState.isEmpty
                    ? const Text('No visits yet — check in on the map!')
                    : Column(
                        children: stats.pointsByState.entries.map((e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.key),
                          trailing: Text('${e.value} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              Text('Visit history', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              visitsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (visits) => visits.isEmpty
                    ? const Text('No visits yet.')
                    : Column(
                        children: visits.map((v) => Card(
                          child: ListTile(
                            leading: Icon(v.source.name == 'gps' ? Icons.my_location : Icons.photo, color: const Color(0xFF0D9488)),
                            title: Text(v.placeName),
                            subtitle: Text('${v.district}, ${v.state} · ${DateFormat.yMMMd().format(v.visitedAt)}'),
                            trailing: Text('+${v.pointsEarned}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                          ),
                        )).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _initialFor(String displayName, String email) {
    final source = displayName.isNotEmpty ? displayName : email;
    if (source.isEmpty) return '?';
    return source[0].toUpperCase();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
