import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/places_tree.dart';
import '../../providers/providers.dart';

// ── Scope enum ────────────────────────────────────────────────────────────────

enum _Scope { national, state, district }

// ── Screen ────────────────────────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  var _scope = _Scope.national;
  String? _selectedState;
  String? _selectedDistrict;

  LeaderboardFilterParams get _params => switch (_scope) {
        _Scope.national => const LeaderboardFilterParams(),
        _Scope.state => LeaderboardFilterParams(state: _selectedState),
        _Scope.district => LeaderboardFilterParams(district: _selectedDistrict),
      };

  String get _filterLabel {
    if (_scope == _Scope.state) return _selectedState ?? 'Pick a state';
    if (_scope == _Scope.district) {
      if (_selectedState != null && _selectedDistrict != null) {
        return '$_selectedState  ›  $_selectedDistrict';
      }
      return 'Pick a district';
    }
    return '';
  }

  Future<void> _openPicker() async {
    final tree = ref.read(placesTreeProvider).valueOrNull;
    if (tree == null) return;

    if (_scope == _Scope.state) {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _StatePicker(tree: tree, initialState: _selectedState),
      );
      if (result != null) setState(() => _selectedState = result);
    } else {
      final result = await showModalBottomSheet<({String state, String district})>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _DistrictPicker(
          tree: tree,
          initialState: _selectedState,
          initialDistrict: _selectedDistrict,
        ),
      );
      if (result != null) {
        setState(() {
          _selectedState = result.state;
          _selectedDistrict = result.district;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final boardAsync = ref.watch(leaderboardByFilterProvider(_params));
    final treeAsync = ref.watch(placesTreeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ranks')),
      body: Column(
        children: [
          // ── Scope selector ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_Scope>(
              segments: const [
                ButtonSegment(value: _Scope.national, label: Text('National'), icon: Icon(Icons.public_rounded)),
                ButtonSegment(value: _Scope.state, label: Text('State'), icon: Icon(Icons.map_outlined)),
                ButtonSegment(value: _Scope.district, label: Text('District'), icon: Icon(Icons.location_city_rounded)),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          // ── Location filter chip ──────────────────────────────────────────
          if (_scope != _Scope.national)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: treeAsync.isLoading
                    ? const LinearProgressIndicator(minHeight: 2)
                    : OutlinedButton.icon(
                        onPressed: _openPicker,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          _filterLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
              ),
            ),
          const SizedBox(height: 8),
          // ── Board ─────────────────────────────────────────────────────────
          Expanded(
            child: _shouldShowBoard
                ? boardAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Could not load leaderboard\n$e',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    data: (entries) => entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.leaderboard_rounded, size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('No results yet',
                                    style: TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: entries.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _BoardTile(
                                rank: i + 1,
                                entry: entries[i],
                                isCurrentUser: entries[i].userId == auth?.userId,
                              ),
                            ),
                          ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_alt_outlined, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _scope == _Scope.state
                                ? 'Tap the button above to pick a state'
                                : 'Tap the button above to pick a district',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool get _shouldShowBoard {
    if (_scope == _Scope.national) return true;
    if (_scope == _Scope.state) return _selectedState != null;
    return _selectedDistrict != null;
  }
}

// ── Board tile ────────────────────────────────────────────────────────────────

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.rank, required this.entry, required this.isCurrentUser});

  final int rank;
  final ApiLeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final medal = rank <= 3;
    const medalColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    final medalColor = medal ? medalColors[rank - 1] : Colors.grey.shade200;

    return Card(
      color: isCurrentUser ? AppColors.primary.withAlpha(20) : null,
      shape: isCurrentUser
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.primary.withAlpha(80)),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: medal ? medalColor : Colors.grey.shade200,
          child: Text(
            medal ? const ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
            style: TextStyle(
              fontSize: medal ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: medal ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.userName,
                style: TextStyle(
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                  color: isCurrentUser ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withAlpha(80)),
                ),
                child: const Text('You',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.score}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: rank == 1 ? const Color(0xFFB45309) : AppColors.textPrimary,
              ),
            ),
            const Text('pts', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

}

// ── State-only picker bottom sheet ────────────────────────────────────────────

class _StatePicker extends StatefulWidget {
  const _StatePicker({required this.tree, required this.initialState});
  final PlacesTree tree;
  final String? initialState;

  @override
  State<_StatePicker> createState() => _StatePickerState();
}

class _StatePickerState extends State<_StatePicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final filtered = widget.tree.states
        .where((s) => s.state.toLowerCase().contains(query))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search state…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); setState(() {}); })
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                final selected = s.state == widget.initialState;
                return ListTile(
                  title: Text(s.state),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () => Navigator.pop(context, s.state),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── District picker bottom sheet (two-column) ─────────────────────────────────

class _DistrictPicker extends StatefulWidget {
  const _DistrictPicker({required this.tree, required this.initialState, required this.initialDistrict});
  final PlacesTree tree;
  final String? initialState;
  final String? initialDistrict;

  @override
  State<_DistrictPicker> createState() => _DistrictPickerState();
}

class _DistrictPickerState extends State<_DistrictPicker> {
  late String _activeState;

  @override
  void initState() {
    super.initState();
    _activeState = widget.initialState ?? widget.tree.states.first.state;
  }

  @override
  Widget build(BuildContext context) {
    final districts = widget.tree.districtsFor(_activeState);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Select district', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── States pane ───────────────────────────────────────────
                SizedBox(
                  width: 150,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    child: ListView.builder(
                      itemCount: widget.tree.states.length,
                      itemBuilder: (context, i) {
                        final s = widget.tree.states[i];
                        final active = s.state == _activeState;
                        return InkWell(
                          onTap: () => setState(() => _activeState = s.state),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: active
                                  ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
                                  : null,
                              color: active ? AppColors.primary.withAlpha(15) : Colors.transparent,
                            ),
                            child: Text(
                              s.state,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                color: active ? AppColors.primaryDark : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // ── Districts pane ────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    itemCount: districts.length,
                    itemBuilder: (context, i) {
                      final d = districts[i];
                      final selected = d == widget.initialDistrict && _activeState == widget.initialState;
                      return ListTile(
                        dense: true,
                        title: Text(d),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        trailing: selected ? const Icon(Icons.check_rounded, size: 16, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(context, (state: _activeState, district: d)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
