/// The closed catalogue with stable persisted identifiers.
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

  static const moreOrder = [
    QuickAction.buy,
    QuickAction.sell,
    QuickAction.pay,
    QuickAction.exchange,
    QuickAction.settings,
    QuickAction.support,
    QuickAction.priceHistory,
    QuickAction.map,
    QuickAction.transfer,
    QuickAction.history,
  ];

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
    // Preserve the saved selection, including an empty or unavailable one.
    // Settings is only a display fallback, never an implicit preference write.
    if (selected.isEmpty && available.contains(QuickAction.settings)) {
      selected.add(QuickAction.settings);
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
        moreOrder.where(
          (action) =>
              available.contains(action) && primary.contains(action) == false,
        ),
      ),
    );
  }
}
