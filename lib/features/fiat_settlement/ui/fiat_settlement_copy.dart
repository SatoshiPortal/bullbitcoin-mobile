import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:flutter/widgets.dart';

/// Localized-copy helpers for fiat settlement. The per-currency withdrawal
/// disclosures are approved content living in the app's localized strings
/// (English is the approved fallback for locales without a translation).
extension FiatSettlementCopyX on BuildContext {
  /// The approved withdrawal-method disclosure for [currency].
  String fiatSettlementDisclosure(FiatCurrency currency) {
    switch (currency) {
      case FiatCurrency.cad:
        return loc.getPaidFiatSettlementDisclosureCad;
      case FiatCurrency.eur:
        return loc.getPaidFiatSettlementDisclosureEur;
      case FiatCurrency.mxn:
        return loc.getPaidFiatSettlementDisclosureMxn;
      case FiatCurrency.crc:
        return loc.getPaidFiatSettlementDisclosureCrc;
      case FiatCurrency.cop:
        return loc.getPaidFiatSettlementDisclosureCop;
      case FiatCurrency.ars:
        return loc.getPaidFiatSettlementDisclosureArs;
      case FiatCurrency.usd:
        return loc.getPaidFiatSettlementDisclosureUsd;
    }
  }

  /// The per-product success headline shown above the chooser when the editor
  /// is opened right after an activation completes. Invoices have no activation
  /// moment, so they fall back to the generic section title.
  String fiatSettlementActivatedTitle(FiatSettlementProduct product) {
    switch (product) {
      case FiatSettlementProduct.lightningAddress:
        return loc.getPaidFiatSettlementActivatedTitleLightningAddress;
      case FiatSettlementProduct.paymentPage:
        return loc.getPaidFiatSettlementActivatedTitlePaymentPage;
      case FiatSettlementProduct.pos:
        return loc.getPaidFiatSettlementActivatedTitlePos;
      case FiatSettlementProduct.invoice:
        return loc.getPaidFiatSettlementSectionTitle;
    }
  }

  /// The saved-configuration summary shown on Get Paid slots / product screens.
  String fiatSettlementSummary(FiatSettlementProductConfig config) {
    switch (config.mode) {
      case FiatSettlementMode.bitcoinOnly:
        return loc.getPaidFiatSettlementSummaryBitcoinOnly;
      case FiatSettlementMode.fiatOnly:
        return loc.getPaidFiatSettlementSummaryFiatOnly(
          config.currency?.code ?? '',
        );
      case FiatSettlementMode.mixed:
        return loc.getPaidFiatSettlementSummaryMixed(
          100 - config.fiatPercentage,
          config.fiatPercentage,
          config.currency?.code ?? '',
        );
    }
  }
}
