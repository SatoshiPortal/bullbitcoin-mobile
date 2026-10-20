enum ConfidentialSepaAvailability {
  /// The user's account cannot use Confidential SEPA.
  unavailable,

  /// The user can use it once their virtual IBAN is active.
  needsVirtualIban,

  ready,
}
