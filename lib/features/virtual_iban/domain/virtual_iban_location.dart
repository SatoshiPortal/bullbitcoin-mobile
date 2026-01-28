/// Enum representing the context/location from which the Virtual IBAN
/// activation flow is accessed.
///
/// This is used to provide context-aware UI messaging and navigation.
enum VirtualIbanLocation {
  /// Accessed from the Fund Exchange feature (depositing EUR)
  funding,

  /// Accessed from the Sell feature (receiving EUR payout)
  sell,

  /// Accessed from the Withdraw feature (withdrawing EUR balance)
  withdraw,
}


