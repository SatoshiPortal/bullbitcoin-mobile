import 'package:material_ui/material_ui.dart';

import 'bull_theme.dart';

/// Neutral selected-row fill shared by sheet and dropdown choices.
Color bullSelectionFill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.bull.surfaceContainer
    : context.bull.textMuted.withValues(alpha: 0.1);
