class BullnymRegisterResult {
  final String nym;
  final String lightningAddress;

  const BullnymRegisterResult({
    required this.nym,
    required this.lightningAddress,
  });
}

class BullnymLookupResult {
  final String nym;
  final bool active;
  final String? lightningAddress;

  const BullnymLookupResult({
    required this.nym,
    required this.active,
    this.lightningAddress,
  });
}
