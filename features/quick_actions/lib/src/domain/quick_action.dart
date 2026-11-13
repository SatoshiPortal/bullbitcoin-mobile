/// The closed catalogue, in the order used by the More sheet.
enum QuickAction {
  map('map'),
  transfer('transfer'),
  history('history'),
  settings('settings'),
  buy('buy'),
  sell('sell'),
  pay('pay'),
  exchange('exchange'),
  support('support'),
  priceHistory('priceHistory');

  const QuickAction(this.id);
  final String id;
}

/// A custom ordered selection of distinct actions.
final class QuickActionSelection {
  QuickActionSelection(Iterable<QuickAction> actions)
    : actions = List.unmodifiable(actions) {
    if (this.actions.toSet().length != this.actions.length) {
      throw ArgumentError('A selection must contain distinct actions');
    }
  }

  final List<QuickAction> actions;
}

/// The visible selection and its canonical complement.
final class QuickActionsLayout {
  QuickActionsLayout._(this.primary, this.more);

  static const int maximumCells = 4;

  final List<QuickAction> primary;
  final List<QuickAction> more;

  factory QuickActionsLayout.resolve({
    required Set<QuickAction> available,
    required List<QuickAction> defaults,
    QuickActionSelection? selection,
  }) {
    final requested = selection?.actions ?? defaults;
    final selected = <QuickAction>[];
    for (final action in requested) {
      if (available.contains(action) && selected.contains(action) == false) {
        selected.add(action);
      }
    }
    final candidate = selected.take(maximumCells).toList();
    final needsMore = available.any(
      (action) => candidate.contains(action) == false,
    );
    final primary = selected
        .take(needsMore ? maximumCells - 1 : maximumCells)
        .toList();
    return QuickActionsLayout._(
      List.unmodifiable(primary),
      List.unmodifiable(
        QuickAction.values.where(
          (action) =>
              available.contains(action) && primary.contains(action) == false,
        ),
      ),
    );
  }
}
