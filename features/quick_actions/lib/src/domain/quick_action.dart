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

  /// Replaces available favorites while retaining unavailable preferences.
  QuickActionSelection withHomeActions({
    required Set<QuickAction> available,
    required Iterable<QuickAction> home,
  }) {
    final replacement = home.toList();
    if (replacement.length > QuickActionsLayout.maximumHomeActions ||
        replacement.toSet().length != replacement.length ||
        replacement.any((action) => !available.contains(action))) {
      throw ArgumentError(
        'Home actions must be distinct, available, and at most three',
      );
    }
    final result = <QuickAction>[];
    var index = 0;
    for (final action in actions) {
      if (!available.contains(action)) {
        result.add(action);
      } else if (index < replacement.length) {
        result.add(replacement[index++]);
      }
    }
    result.addAll(replacement.skip(index));
    return QuickActionSelection(result);
  }
}

/// The visible selection and its canonical complement.
final class QuickActionsLayout {
  QuickActionsLayout._(this.primary, this.more);

  static const int maximumCells = 4;
  static const int maximumHomeActions = 3;

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
    final primary = selected.take(maximumHomeActions).toList();
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
