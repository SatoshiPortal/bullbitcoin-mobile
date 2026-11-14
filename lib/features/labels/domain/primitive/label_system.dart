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

  /// Literal that autoswap stored as its transaction label and order note
  /// before it used [LabelSystem.autoSwap]. Published versions wrote it, so it
  /// is still in users' databases; it is only recognized to be displayed, the
  /// stored data is never rewritten and it stays an ordinary, editable label.
  static const legacyAutoTransferLabel = 'Auto-Transfer';

  /// The system label a stored [label] is shown as, or `null` when it is shown
  /// as written.
  static LabelSystem? displayedAs(String label) {
    if (label == legacyAutoTransferLabel) return LabelSystem.autoSwap;
    return isSystemLabel(label) ? fromLabel(label) : null;
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
