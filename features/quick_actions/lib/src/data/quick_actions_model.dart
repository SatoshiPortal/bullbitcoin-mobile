import 'dart:convert';

import '../domain/quick_action.dart';

/// Storage representation; unknown IDs are ignored without rewriting the value.
final class QuickActionsModel {
  const QuickActionsModel(this.ids);
  final List<String> ids;

  factory QuickActionsModel.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List && decoded.every((value) => value is String)) {
      return QuickActionsModel(decoded.cast<String>());
    }
    throw const FormatException('Invalid quick actions preference');
  }

  factory QuickActionsModel.fromSelection(QuickActionSelection selection) =>
      QuickActionsModel(selection.actions.map((action) => action.id).toList());

  QuickActionSelection toSelection() {
    final actions = <QuickAction>[];
    for (final id in ids) {
      for (final action in QuickAction.values) {
        if (action.id == id) actions.add(action);
      }
    }
    if (actions.toSet().length != actions.length) {
      throw const FormatException('Invalid quick actions selection');
    }
    return QuickActionSelection(actions);
  }

  String encode() => jsonEncode(ids);
}
