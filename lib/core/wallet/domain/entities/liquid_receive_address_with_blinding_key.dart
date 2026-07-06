/// A freshly derived confidential Liquid receive address paired with the
/// PER-ADDRESS blinding key hex.
///
/// The blinding key is what a payer/watcher needs to unblind the confidential
/// output and detect payment to this specific address. It is a per-address key
/// (derived for this index), NEVER the wallet master blinding key — only this
/// scoped key leaves the device.
class LiquidReceiveAddressWithBlindingKey {
  final String address;
  final String blindingKeyHex;

  const LiquidReceiveAddressWithBlindingKey({
    required this.address,
    required this.blindingKeyHex,
  });
}
