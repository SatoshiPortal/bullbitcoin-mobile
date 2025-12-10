import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

enum LabelSystem {
  swaps,
  autoSwap,
  payjoin,
  selfSpend,
  exchangeBuy,
  exchangeSell;

  const LabelSystem();

  String get label => switch (this) {
    LabelSystem.swaps => swapLabelSystem,
    LabelSystem.autoSwap => autoSwapLabelSystem,
    LabelSystem.payjoin => payjoinLabelSystem,
    LabelSystem.selfSpend => selfSpendLabelSystem,
    LabelSystem.exchangeBuy => exchangeBuyLabelSystem,
    LabelSystem.exchangeSell => exchangeSellLabelSystem,
  };

  static LabelSystem fromLabel(String label) {
    return switch (label) {
      swapLabelSystem => LabelSystem.swaps,
      autoSwapLabelSystem => LabelSystem.autoSwap,
      payjoinLabelSystem => LabelSystem.payjoin,
      selfSpendLabelSystem => LabelSystem.selfSpend,
      exchangeBuyLabelSystem => LabelSystem.exchangeBuy,
      exchangeSellLabelSystem => LabelSystem.exchangeSell,
      _ => throw ArgumentError('Invalid $LabelSystem: $label'),
    };
  }

  String toTranslatedLabel(BuildContext context) {
    return switch (this) {
      LabelSystem.swaps => context.loc.systemLabelSwaps,
      LabelSystem.autoSwap => context.loc.systemLabelAutoSwap,
      LabelSystem.payjoin => context.loc.systemLabelPayjoin,
      LabelSystem.selfSpend => context.loc.systemLabelSelfSpend,
      LabelSystem.exchangeBuy => context.loc.systemLabelExchangeBuy,
      LabelSystem.exchangeSell => context.loc.systemLabelExchangeSell,
    };
  }

  bool isExchangeRelated() {
    return switch (this) {
      LabelSystem.exchangeBuy => true,
      LabelSystem.exchangeSell => true,
      _ => false,
    };
  }
}
