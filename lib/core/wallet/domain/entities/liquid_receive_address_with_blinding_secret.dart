/// A freshly derived confidential Liquid receive address paired with its
/// per-address blinding secret.
///
/// Bullnym needs this secret to unblind outputs sent to [address]. This is
/// neither the wallet master blinding key nor the public key exposed as
/// `Address.blindingKey` by LWK.
class LiquidReceiveAddressWithBlindingSecret {
  final String address;
  final String blindingSecretHex;

  const LiquidReceiveAddressWithBlindingSecret({
    required this.address,
    required this.blindingSecretHex,
  });
}
