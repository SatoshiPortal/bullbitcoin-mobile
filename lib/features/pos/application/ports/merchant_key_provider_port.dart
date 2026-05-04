class PosMerchantKeys {
  const PosMerchantKeys({
    required this.merchantPrivkey,
    required this.merchantPubkey,
    required this.recoveryPrivkey,
    required this.recoveryPubkey,
  });

  final String merchantPrivkey;
  final String merchantPubkey;
  final String recoveryPrivkey;
  final String recoveryPubkey;
}

abstract class MerchantKeyProviderPort {
  Future<PosMerchantKeys> derive(String masterFingerprint);
}
