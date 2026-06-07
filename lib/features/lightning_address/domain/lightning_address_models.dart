class LightningAddressRegistration {
  final String nym;
  final String lightningAddress;

  const LightningAddressRegistration({
    required this.nym,
    required this.lightningAddress,
  });
}

enum LightningAddressStatusKind { active, inactive }

class LightningAddressStatus {
  final LightningAddressStatusKind kind;
  final String nym;

  const LightningAddressStatus._({required this.kind, required this.nym});

  const LightningAddressStatus.active({required String nym})
    : this._(kind: LightningAddressStatusKind.active, nym: nym);

  const LightningAddressStatus.inactive({required String nym})
    : this._(kind: LightningAddressStatusKind.inactive, nym: nym);
}
