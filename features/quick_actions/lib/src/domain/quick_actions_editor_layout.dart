import 'quick_action.dart';

/// Editable partitions; unlike Home's preview, these never inject Settings.
final class QuickActionsEditorLayout {
  QuickActionsEditorLayout({
    required QuickActionSelection selection,
    required Set<QuickAction> available,
  }) : _selection = selection,
       _available = Set.unmodifiable(available),
       home = List.unmodifiable(
         selection.actions
             .where(available.contains)
             .take(QuickActionsLayout.maximumHomeActions),
       ) {
    more = List.unmodifiable(
      {
        ...selection.more,
        ...QuickActionsLayout.moreOrder,
      }.where((action) => available.contains(action) && !home.contains(action)),
    );
  }

  final QuickActionSelection _selection;
  final Set<QuickAction> _available;
  final List<QuickAction> home;
  late final List<QuickAction> more;

  /// Null is the fixed, non-draggable separator. Indices include it.
  List<QuickAction?> get items => [...home, null, ...more];

  /// Flutter's onReorderItem already supplies a post-removal destination.
  QuickActionSelection move(int from, int to) {
    final ordered = items;
    if (from < 0 ||
        from >= ordered.length ||
        to < 0 ||
        to >= ordered.length ||
        from == to ||
        ordered[from] == null) {
      return _selection;
    }
    final action = ordered.removeAt(from);
    ordered.insert(to, action);
    final boundary = ordered.indexOf(null);
    final nextHome = ordered.take(boundary).whereType<QuickAction>().toList();
    final nextMore = ordered
        .skip(boundary + 1)
        .whereType<QuickAction>()
        .toList();
    if (nextHome.length > QuickActionsLayout.maximumHomeActions) {
      // Eject the previous last Home item, never the newly inserted action.
      final displaced = home.last;
      nextHome.remove(displaced);
      nextMore.insert(0, displaced);
    }
    return QuickActionSelection(
      _replaceAvailable(_selection.actions, nextHome),
      more: _replaceAvailable(_selection.more, nextMore),
    );
  }

  QuickActionSelection moveToHome(QuickAction action) => home.contains(action)
      ? _selection
      : move(items.indexOf(action), home.length);

  QuickActionSelection moveToMore(QuickAction action) => more.contains(action)
      ? _selection
      : move(items.indexOf(action), home.length);

  /// Drops [action] on [target]'s cell: within a zone it takes that cell,
  /// across zones it lands before [target]. A full Home ejects its last action.
  QuickActionSelection dropOn(QuickAction action, QuickAction target) {
    final ordered = items;
    final from = ordered.indexOf(action);
    final to = ordered.indexOf(target);
    if (from < 0 || to < 0 || from == to) return _selection;
    final sameZone = home.contains(action) == home.contains(target);
    return move(from, sameZone || from > to ? to : to - 1);
  }

  /// Drops [action] after the last action of Home or of More.
  QuickActionSelection dropAtEnd(QuickAction action, {required bool onHome}) {
    final from = items.indexOf(action);
    if (from < 0) return _selection;
    if (!onHome) return move(from, items.length - 1);
    return move(from, home.contains(action) ? home.length - 1 : home.length);
  }

  List<QuickAction> _replaceAvailable(
    List<QuickAction> original,
    List<QuickAction> replacement,
  ) {
    final result = <QuickAction>[];
    var index = 0;
    for (final action in original) {
      if (!_available.contains(action)) {
        result.add(action);
      } else if (index < replacement.length) {
        result.add(replacement[index++]);
      }
    }
    return [...result, ...replacement.skip(index)];
  }
}
