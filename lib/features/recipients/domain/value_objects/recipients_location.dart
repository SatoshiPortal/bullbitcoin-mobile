/// Context from which recipients screen is accessed.
/// Determines Virtual IBAN eligibility and flow behavior.
enum RecipientsLocation {
  /// Account management view - standard tabs flow
  accountsView,

  /// Pay flow - third-party payments, uses step-based flow (NO VIBAN activation)
  payView,

  /// Sell flow - receive fiat to YOUR account (VIBAN eligible)
  sellView,

  /// Withdraw flow - withdraw fiat to YOUR account (VIBAN eligible)
  withdrawView,
}

extension RecipientsLocationX on RecipientsLocation {
  /// Whether Virtual IBAN activation is available for this location.
  /// Only withdraw can activate VIBAN (deposit uses fund_exchange flow).
  bool get isVirtualIbanEligible => this == RecipientsLocation.withdrawView;

  /// Whether only owner recipients should be shown
  bool get requiresOwnerRecipients =>
      this == RecipientsLocation.sellView ||
      this == RecipientsLocation.withdrawView;

  /// Whether this location uses the step-based flow (type selection → form/list).
  /// All flows except accountsView use step-based navigation.
  bool get usesStepBasedFlow => this != RecipientsLocation.accountsView;
}
