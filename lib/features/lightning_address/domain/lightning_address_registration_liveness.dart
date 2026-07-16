enum LightningAddressRegistrationLiveness {
  live,
  reregistered,
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
