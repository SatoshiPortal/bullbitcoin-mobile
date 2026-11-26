import 'package:flutter/widgets.dart';

import 'exchange_l10n.dart';

/// Localized copy for the exchange landing.
final class ExchangeLandingCopy {
  final String brandName;
  final String connectAccount;
  final String recommendedExchange;
  final String selfCustody;
  final String recurringOrders;
  final String sellBitcoin;
  final String bankTransfers;
  final String customerSupport;
  final String unifiedHistory;
  final String legalDisclaimer;
  final String unavailableDisclaimer;
  final String signIn;
  final String openWebsite;

  const ExchangeLandingCopy({
    required this.brandName,
    required this.connectAccount,
    required this.recommendedExchange,
    required this.selfCustody,
    required this.recurringOrders,
    required this.sellBitcoin,
    required this.bankTransfers,
    required this.customerSupport,
    required this.unifiedHistory,
    required this.legalDisclaimer,
    required this.unavailableDisclaimer,
    required this.signIn,
    required this.openWebsite,
  });

  factory ExchangeLandingCopy.of(BuildContext context) {
    final loc = context.loc;
    return ExchangeLandingCopy(
      brandName: loc.exchangeBrandName,
      connectAccount: loc.exchangeLandingConnectAccount,
      recommendedExchange: loc.exchangeLandingRecommendedExchange,
      selfCustody: loc.exchangeFeatureSelfCustody,
      recurringOrders: loc.exchangeFeatureDcaOrders,
      sellBitcoin: loc.exchangeFeatureSellBitcoin,
      bankTransfers: loc.exchangeFeatureBankTransfers,
      customerSupport: loc.exchangeFeatureCustomerSupport,
      unifiedHistory: loc.exchangeFeatureUnifiedHistory,
      legalDisclaimer: loc.exchangeLandingDisclaimerLegal,
      unavailableDisclaimer: loc.exchangeLandingDisclaimerNotAvailable,
      signIn: loc.exchangeLoginButton,
      openWebsite: loc.exchangeGoToWebsiteButton,
    );
  }
}
