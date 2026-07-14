import 'dart:typed_data';

/// Internal feature-domain representation of a derived child seed.
///
/// It deliberately stays behind [DeterministicWalletsFacade] and prevents core
/// seed entities, mnemonics, seed bytes, or extended private keys from crossing
/// the public feature boundary.
final class DeterministicWalletSeedMaterial {
  final List<String> _mnemonicWords;
  final Uint8List _seedBytes;
  final String masterFingerprint;

  DeterministicWalletSeedMaterial({
    required List<String> mnemonicWords,
    required Uint8List seedBytes,
    required this.masterFingerprint,
  }) : _mnemonicWords = List.unmodifiable(mnemonicWords),
       _seedBytes = Uint8List.fromList(seedBytes);

  List<String> get mnemonicWords => List.unmodifiable(_mnemonicWords);

  Uint8List get seedBytes => Uint8List.fromList(_seedBytes);
}
