import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

enum LabelSystem {
  swaps,
  autoSwap,
  payjoin,
  selfSpend,
  exchangeBuy,
  exchangeSell,
  invoice,
  lightningAddress,
  paymentPage,
  pointOfSale,
  btcpay;

  const LabelSystem();

  String get label => switch (this) {
    LabelSystem.swaps => swapLabelSystem,
    LabelSystem.autoSwap => autoSwapLabelSystem,
    LabelSystem.payjoin => payjoinLabelSystem,
    LabelSystem.selfSpend => selfSpendLabelSystem,
    LabelSystem.exchangeBuy => exchangeBuyLabelSystem,
    LabelSystem.exchangeSell => exchangeSellLabelSystem,
    LabelSystem.invoice => invoiceLabelSystem,
    LabelSystem.lightningAddress => lightningAddressLabelSystem,
    LabelSystem.paymentPage => paymentPageLabelSystem,
    LabelSystem.pointOfSale => posLabelSystem,
    LabelSystem.btcpay => btcpayLabelSystem,
  };

  static LabelSystem fromLabel(String label) {
    return switch (label) {
      swapLabelSystem => LabelSystem.swaps,
      autoSwapLabelSystem => LabelSystem.autoSwap,
      payjoinLabelSystem => LabelSystem.payjoin,
      selfSpendLabelSystem => LabelSystem.selfSpend,
      exchangeBuyLabelSystem => LabelSystem.exchangeBuy,
      exchangeSellLabelSystem => LabelSystem.exchangeSell,
      invoiceLabelSystem => LabelSystem.invoice,
      lightningAddressLabelSystem => LabelSystem.lightningAddress,
      paymentPageLabelSystem => LabelSystem.paymentPage,
      posLabelSystem => LabelSystem.pointOfSale,
      btcpayLabelSystem => LabelSystem.btcpay,
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
      LabelSystem.selfSpend => context.loc.systemLabelSelfSpend,
      LabelSystem.exchangeBuy => context.loc.systemLabelExchangeBuy,
      LabelSystem.exchangeSell => context.loc.systemLabelExchangeSell,
      LabelSystem.invoice => context.loc.systemLabelInvoice,
      // Reuse the existing product-name strings so these labels track the same
      // wording (and translations) shown on the Get Paid dashboard cards.
      LabelSystem.lightningAddress =>
        context.loc.getPaidDashboardLightningAddressTitle,
      LabelSystem.paymentPage => context.loc.getPaidDashboardDonationPageTitle,
      LabelSystem.pointOfSale => context.loc.getPaidDashboardPosTitle,
      LabelSystem.btcpay => context.loc.btcpaySettingsTitle,
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
