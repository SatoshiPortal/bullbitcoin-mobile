enum LightningAddressRegistrationLiveness {
  live,

  /// A legacy registration was inactive with a known nym and a silent
  /// re-register succeeded. Permanent-name registrations never use this state.
  reregistered,

  /// Genuinely missing, an intentional permanent-name offline state, or a
  /// legacy re-register rejection. The UI offers product reactivation without
  /// offering a different name.
  needsReactivation,
  unreachable,
}

final class LightningAddressHealOutcome {
  final LightningAddressRegistrationLiveness liveness;
  final String? nym;
  final String? lightningAddress;

  const LightningAddressHealOutcome({
    required this.liveness,
    this.nym,
    this.lightningAddress,
  });
}
