import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized name for each [LabelSystem].
///
/// A presentation extension for the same reason failures have one: with
/// `BuildContext` on the enum, `label_system.dart` had to import
/// `flutter/material`, which put Flutter in `domain/` and in every file that
/// reached the primitive through it.
extension LabelSystemL10n on LabelSystem {
  String toTranslatedLabel(BuildContext context) => switch (this) {
    LabelSystem.swaps => context.loc.systemLabelSwaps,
    LabelSystem.autoSwap => context.loc.systemLabelAutoSwap,
    LabelSystem.payjoin => context.loc.systemLabelPayjoin,
    LabelSystem.selfSpend => context.loc.systemLabelSelfSpend,
    LabelSystem.exchangeBuy => context.loc.systemLabelExchangeBuy,
    LabelSystem.exchangeSell => context.loc.systemLabelExchangeSell,
  };
}
