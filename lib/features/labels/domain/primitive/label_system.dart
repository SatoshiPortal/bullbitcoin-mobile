import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

enum LabelSystem {
  swaps,
  autoSwap,
  payjoin,

  /// A UTXO the wallet contributed as an input to a payjoin proposal it
  /// sent out — distinct from [payjoin], which tags a TRANSACTION that
  /// actually completed via a real payjoin. Applied the moment a proposal
  /// is built and sent, before either side knows whether the negotiation
  /// will complete, and deliberately never removed if it doesn't: sharing
  /// the proposal already revealed this coin's existence and ownership to
  /// the counterparty (BIP78), so the exposure is real regardless of
  /// whether a transaction was ever broadcast. Also drives "prefer
  /// re-contributing an already-exposed coin" on the next attempt instead
  /// of burning a fresh one.
  payjoinExposed,
  selfSpend,
  exchangeBuy,
  exchangeSell;

  const LabelSystem();

  String get label => switch (this) {
    LabelSystem.swaps => swapLabelSystem,
    LabelSystem.autoSwap => autoSwapLabelSystem,
    LabelSystem.payjoin => payjoinLabelSystem,
    LabelSystem.payjoinExposed => payjoinExposedLabelSystem,
    LabelSystem.selfSpend => selfSpendLabelSystem,
    LabelSystem.exchangeBuy => exchangeBuyLabelSystem,
    LabelSystem.exchangeSell => exchangeSellLabelSystem,
  };

  static LabelSystem fromLabel(String label) {
    return switch (label) {
      swapLabelSystem => LabelSystem.swaps,
      autoSwapLabelSystem => LabelSystem.autoSwap,
      payjoinLabelSystem => LabelSystem.payjoin,
      payjoinExposedLabelSystem => LabelSystem.payjoinExposed,
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

  String toTranslatedLabel(BuildContext context) {
    return switch (this) {
      LabelSystem.swaps => context.loc.systemLabelSwaps,
      LabelSystem.autoSwap => context.loc.systemLabelAutoSwap,
      LabelSystem.payjoin => context.loc.systemLabelPayjoin,
      LabelSystem.payjoinExposed => context.loc.systemLabelPayjoinExposed,
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
