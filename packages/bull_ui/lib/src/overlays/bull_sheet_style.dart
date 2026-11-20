import 'package:material_ui/material_ui.dart';

import '../theme/bull_theme.dart';

/// Explicit colors for one modal sheet; legacy sheet defaults remain unchanged.
@immutable
class BullSheetStyle {
  const BullSheetStyle({
    required this.barrierColor,
    required this.backgroundColor,
  });

  /// Shared Send/Receive treatment: a dark scrim and the themed sheet surface.
  factory BullSheetStyle.redesign(BuildContext context) => BullSheetStyle(
    barrierColor: context.bull.scrim.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.60 : 0.45,
    ),
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? context.bull.background
        : context.bull.surface,
  );

  final Color barrierColor;
  final Color backgroundColor;
}
