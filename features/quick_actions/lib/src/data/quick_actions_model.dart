import 'dart:convert';

import '../domain/quick_action.dart';

/// Storage representation; unknown IDs are ignored without rewriting the value.
final class QuickActionsModel {
  const QuickActionsModel(this.ids, {this.moreIds = const []});
  final List<String> ids;
  final List<String> moreIds;

  factory QuickActionsModel.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> &&
        decoded.length == 2 &&
        decoded.containsKey('home') &&
        decoded.containsKey('more')) {
      final home = decoded['home'];
      final more = decoded['more'];
      if (home is List &&
          more is List &&
          home.every((value) => value is String) &&
          more.every((value) => value is String)) {
        return QuickActionsModel(
          home.cast<String>(),
          moreIds: more.cast<String>(),
        );
      }
    }
    throw const FormatException('Invalid quick actions preference');
  }

  factory QuickActionsModel.fromSelection(QuickActionSelection selection) =>
      QuickActionsModel(
        selection.actions.map((action) => action.id).toList(),
        moreIds: selection.more.map((action) => action.id).toList(),
      );

  QuickActionSelection toSelection() {
    List<QuickAction> known(List<String> values) => [
      for (final id in values)
        for (final action in QuickAction.values)
          if (action.id == id) action,
    ];
    final actions = known(ids);
    final more = known(moreIds);
    final combined = [...actions, ...more];
    if (combined.toSet().length != combined.length) {
      throw const FormatException('Invalid quick actions selection');
    }
    return QuickActionSelection(actions, more: more);
  }

  String encode() => jsonEncode({'home': ids, 'more': moreIds});
}
