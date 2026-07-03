class LightningAddressRegistration {
  final String nym;
  final String lightningAddress;

  const LightningAddressRegistration({
    required this.nym,
    required this.lightningAddress,
  });
}

class LightningAddressStatus {
  final String nym;
  final bool active;
  final String? lightningAddress;

  const LightningAddressStatus({
    required this.nym,
    required this.active,
    this.lightningAddress,
  });
}
