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

  const BullnymLookupResult({required this.nym, required this.active});
}
