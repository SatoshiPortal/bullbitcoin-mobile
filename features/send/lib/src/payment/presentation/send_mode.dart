/// Which kind of send the screens are driving.
///
/// Sealed rather than a boolean so the two modes cannot half-disagree: the SP
/// case carries the label the shared screens need, instead of a flag plus a
/// nullable label that only mean something together.
sealed class SendMode {
  const SendMode();
}

/// The bitcoin and liquid flow: a wallet is picked, coins are selected, a PSBT
/// is built and signed locally or on a device.
final class SendModeBitcoin extends SendMode {
  const SendModeBitcoin();
}

/// The Silent Payments flow. There is no wallet to pick and nothing is signed
/// here: the spend is simulated, built and broadcast on the Rust side.
final class SendModeSp extends SendMode {
  /// Localized name for the SP wallet, shown wherever the screens name the
  /// wallet being sent from.
  final String walletLabel;

  const SendModeSp({required this.walletLabel});
}
