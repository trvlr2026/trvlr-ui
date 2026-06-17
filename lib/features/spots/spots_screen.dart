import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/place.dart';
import '../../providers/providers.dart';

class SpotsScreen extends ConsumerStatefulWidget {
  const SpotsScreen({super.key});

  @override
  ConsumerState<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends ConsumerState<SpotsScreen> {
  String _selectedState = 'Karnataka';
  String _selectedDistrict = 'Bengaluru Urban';

  void _onStateChanged(String? newState) {
    if (newState == null || newState == _selectedState) return;
    final tree = ref.read(placesTreeProvider).valueOrNull;
    final districts = tree?.districtsFor(newState) ?? [];
    setState(() {
      _selectedState = newState;
      _selectedDistrict = districts.isNotEmpty ? districts.first : '';
    });
  }

  void _onDistrictChanged(String? newDistrict) {
    if (newDistrict == null || newDistrict == _selectedDistrict) return;
    setState(() => _selectedDistrict = newDistrict);
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(placesTreeProvider);
    final spotsAsync = ref.watch(
      spotsByFilterProvider(SpotsFilterParams(state: _selectedState, district: _selectedDistrict)),
    );

    final stateNames = treeAsync.valueOrNull?.states.map((s) => s.state).toList() ?? [_selectedState];
    final districts = treeAsync.valueOrNull?.districtsFor(_selectedState) ?? [_selectedDistrict];

    // Keep selections valid when tree loads
    final validState = stateNames.contains(_selectedState) ? _selectedState : stateNames.first;
    final validDistrict = districts.contains(_selectedDistrict) ? _selectedDistrict : (districts.isNotEmpty ? districts.first : '');

    return Scaffold(
      appBar: AppBar(title: const Text('Spots')),
      body: Column(
        children: [
          _FilterBar(
            states: stateNames,
            districts: districts,
            selectedState: validState,
            selectedDistrict: validDistrict,
            treeLoading: treeAsync.isLoading,
            onStateChanged: _onStateChanged,
            onDistrictChanged: _onDistrictChanged,
          ),
          if (spotsAsync.isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: spotsAsync.when(
              loading: () => const _LoadingView(),
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(
                  spotsByFilterProvider(SpotsFilterParams(state: _selectedState, district: _selectedDistrict)),
                ),
              ),
              data: (spots) {
                if (spots.isEmpty) {
                  return _EmptyView(district: _selectedDistrict);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: spots.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SpotCard(place: spots[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.states,
    required this.districts,
    required this.selectedState,
    required this.selectedDistrict,
    required this.treeLoading,
    required this.onStateChanged,
    required this.onDistrictChanged,
  });

  final List<String> states;
  final List<String> districts;
  final String selectedState;
  final String selectedDistrict;
  final bool treeLoading;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onDistrictChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown(
              label: 'State',
              value: selectedState,
              items: states,
              enabled: !treeLoading,
              onChanged: onStateChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FilterDropdown(
              label: 'District',
              value: selectedDistrict,
              items: districts,
              enabled: !treeLoading && districts.isNotEmpty,
              onChanged: onDistrictChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: items
          .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

// ── Spot card ─────────────────────────────────────────────────────────────────

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final tags = _parseTags(place.category);
    final accentColor = _categoryColor(place.category);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          if (place.district.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              place.district,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: tags
                                  .map((t) => _SpotTag(label: t, color: accentColor))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Points badge
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withAlpha(60)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${place.pointsValue}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Text(
                                'pts',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "tourism:hostel" → ["tourism", "hostel"]
  static List<String> _parseTags(String category) {
    if (category.isEmpty) return [];
    return category.split(':').map((s) => s.replaceAll('_', ' ')).toList();
  }

  static Color _categoryColor(String category) {
    final type = category.split(':').last;
    return switch (type) {
      'park' || 'nature_reserve' || 'forest' || 'garden' => const Color(0xFF16A34A),
      'museum' || 'gallery' || 'artwork' => const Color(0xFF7C3AED),
      'beach' || 'lake' || 'river' => const Color(0xFF0284C7),
      'temple' || 'church' || 'mosque' || 'place_of_worship' => const Color(0xFFD97706),
      'restaurant' || 'cafe' || 'bar' => const Color(0xFFEA580C),
      'hostel' || 'hotel' => const Color(0xFF0891B2),
      'playground' || 'sports_centre' => const Color(0xFFDC2626),
      _ => AppColors.primary,
    };
  }
}

class _SpotTag extends StatelessWidget {
  const _SpotTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Empty / error / loading views ─────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Could not load spots', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.district});

  final String district;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No spots found', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'No spots have been added for $district yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
