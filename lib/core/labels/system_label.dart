import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

enum SystemLabel {
  swaps,
  autoSwap,
  payjoin,
  selfSpend,
  exchangeBuy,
  exchangeSell;

  const SystemLabel();

  // database label modifying this value leads to a breaking change
  String get label => switch (this) {
    SystemLabel.swaps => swapSystemLabel,
    SystemLabel.autoSwap => autoSwapSystemLabel,
    SystemLabel.payjoin => payjoinSystemLabel,
    SystemLabel.selfSpend => selfSpendSystemLabel,
    SystemLabel.exchangeBuy => exchangeBuySystemLabel,
    SystemLabel.exchangeSell => exchangeSellSystemLabel,
  };

  static SystemLabel fromLabel(String label) {
    return switch (label) {
      swapSystemLabel => SystemLabel.swaps,
      autoSwapSystemLabel => SystemLabel.autoSwap,
      payjoinSystemLabel => SystemLabel.payjoin,
      selfSpendSystemLabel => SystemLabel.selfSpend,
      exchangeBuySystemLabel => SystemLabel.exchangeBuy,
      exchangeSellSystemLabel => SystemLabel.exchangeSell,
      _ => throw ArgumentError('Invalid $SystemLabel: $label'),
    };
  }

  String toTranslatedLabel(BuildContext context) {
    return switch (this) {
      SystemLabel.swaps => context.loc.systemLabelSwaps,
      SystemLabel.autoSwap => context.loc.systemLabelAutoSwap,
      SystemLabel.payjoin => context.loc.systemLabelPayjoin,
      SystemLabel.selfSpend => context.loc.systemLabelSelfSpend,
      SystemLabel.exchangeBuy => context.loc.systemLabelExchangeBuy,
      SystemLabel.exchangeSell => context.loc.systemLabelExchangeSell,
    };
  }

  bool isExchangeRelated() {
    return switch (this) {
      SystemLabel.exchangeBuy => true,
      SystemLabel.exchangeSell => true,
      _ => false,
    };
  }
}
