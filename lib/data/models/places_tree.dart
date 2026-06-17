class StateNode {
  const StateNode({required this.state, required this.districts});

  final String state;
  final List<String> districts;
}

class PlacesTree {
  const PlacesTree({required this.states});

  final List<StateNode> states;

  /// All district names across all states (for validation / lookup).
  List<String> districtsFor(String state) =>
      states.firstWhere((s) => s.state == state, orElse: () => const StateNode(state: '', districts: [])).districts;
}
