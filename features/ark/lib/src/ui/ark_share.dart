import 'package:bull_ui/bull_ui.dart' show BuildContext;

/// Host platform effect; [isCurrent] binds feedback to the live sheet action.
typedef ArkShare = Future<void> Function(
  BuildContext context,
  String value, {
  required bool Function() isCurrent,
});
