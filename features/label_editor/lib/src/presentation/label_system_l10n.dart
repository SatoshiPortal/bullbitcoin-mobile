import 'package:flutter/widgets.dart';
import 'package:labels/labels.dart';

import '../label_editor_l10n.dart';

/// User-facing, localized name for each [LabelSystem].
///
/// A presentation extension for the same reason failures have one: with
/// `BuildContext` on the enum, `label_system.dart` had to import
/// `flutter/material`, which put Flutter in `domain/` and in every file that
/// reached the primitive through it.
extension LabelSystemL10n on LabelSystem {
  String toTranslatedLabel(BuildContext context) => switch (this) {
    LabelSystem.swaps => context.labelLoc.systemLabelSwaps,
    LabelSystem.autoSwap => context.labelLoc.systemLabelAutoSwap,
    LabelSystem.payjoin => context.labelLoc.systemLabelPayjoin,
    LabelSystem.selfSpend => context.labelLoc.systemLabelSelfSpend,
    LabelSystem.exchangeBuy => context.labelLoc.systemLabelExchangeBuy,
    LabelSystem.exchangeSell => context.labelLoc.systemLabelExchangeSell,
  };
}
