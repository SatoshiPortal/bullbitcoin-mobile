import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

/// The BIP39 mnemonic the SP wallet is built from. bwk derives the SP scan/spend
/// keys the standard BIP352 way from this mnemonic, so the same mnemonic yields
/// the same SP wallet as other BIP352 software.
///
/// A non-mnemonic seed here is a programmer error: the setup gate only enables
/// SP for a mnemonic-backed default wallet, so it throws a [StateError] (never
/// caught) rather than a modeled failure.
String spMnemonicFromSeed(Seed seed) {
  if (seed is! MnemonicSeed) {
    throw StateError(
      'SP requires a mnemonic-backed seed; got ${seed.runtimeType}',
    );
  }
  return seed.mnemonicWords.join(' ');
}
