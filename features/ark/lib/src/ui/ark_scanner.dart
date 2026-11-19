import 'package:bull_ui/bull_ui.dart';

/// Host-owned camera presentation; cancellation returns null and text stays raw.
typedef ArkScanner = Future<String?> Function(
  BuildContext context,
  String title,
);
