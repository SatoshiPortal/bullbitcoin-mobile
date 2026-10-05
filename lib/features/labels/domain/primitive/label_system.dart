import 'package:bb_mobile/core/storage/tables/labels_table.dart';

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

  static bool isSystemLabel(String label) {
    try {
      fromLabel(label);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool isExchangeRelated() {
    return switch (this) {
      LabelSystem.exchangeBuy => true,
      LabelSystem.exchangeSell => true,
      _ => false,
    };
  }
}
