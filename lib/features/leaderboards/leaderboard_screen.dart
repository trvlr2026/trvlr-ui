import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/leaderboard_entry.dart';
import '../../data/models/user.dart';
import '../../providers/providers.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _scope;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() => _scope = null);
    });
    _loadDefaultScope();
  }

  Future<void> _loadDefaultScope() async {
    final user = await ref.read(repositoryProvider).getCurrentUser();
    if (!mounted || user == null) return;
    setState(() => _scope = user.homeDistrict);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  LeaderboardLevel get _level => switch (_tabController.index) {
        0 => LeaderboardLevel.district,
        1 => LeaderboardLevel.state,
        _ => LeaderboardLevel.national,
      };

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final params = LeaderboardParams(level: _level, scope: _level == LeaderboardLevel.national ? null : _scope);
    final boardAsync = ref.watch(leaderboardProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'District'),
            Tab(text: 'State'),
            Tab(text: 'National'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_level != LeaderboardLevel.national)
            userAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (user) => _ScopePicker(level: _level, user: user, scope: _scope, onChanged: (s) => setState(() => _scope = s)),
            ),
          Expanded(
            child: boardAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entries) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _LeaderboardTile(entry: entries[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopePicker extends ConsumerWidget {
  const _ScopePicker({required this.level, required this.user, required this.scope, required this.onChanged});
  final LeaderboardLevel level;
  final User? user;
  final String? scope;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final future = level == LeaderboardLevel.district && user != null
        ? repo.getDistrictsForState(user!.homeState)
        : repo.getAllStates();

    return FutureBuilder<List<String>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        final value = scope != null && items.contains(scope) ? scope! : items.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(labelText: level == LeaderboardLevel.district ? 'District' : 'State', isDense: true),
            items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final highlight = entry.isCurrentUser;
    return Card(
      color: highlight ? const Color(0xFF0D9488).withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.rank <= 3 ? const Color(0xFFF59E0B) : const Color(0xFF0D9488),
          child: Text('${entry.rank}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(entry.displayName, style: TextStyle(fontWeight: highlight ? FontWeight.bold : FontWeight.w500)),
        subtitle: Text('${entry.placesVisited} places visited'),
        trailing: Text('${entry.totalPoints}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
