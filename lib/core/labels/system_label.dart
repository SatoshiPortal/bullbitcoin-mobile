import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

enum SystemLabel {
  swaps('swaps'),
  autoSwap('auto-swap'),
  payjoin('payjoin'),
  selfSpend('self-spend'),
  exchangeBuy('exchange_buy'),
  exchangeSell('exchange_sell');

  final String label;

  const SystemLabel(this.label);

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
