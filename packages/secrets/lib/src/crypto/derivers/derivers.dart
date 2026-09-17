/// Everything that derives *from* a secret, one file per source library.
///
/// One of the two ways this package manipulates key material — the other
/// is the signers. Derivation produces keys, descriptors and children;
/// signing produces signatures. Derivers hold no wallet, no network
/// client and no state, which is what lets descriptors and BIP85 work
/// with no chain access at all — and what lets them be static: there is
/// nothing to inject and nothing to mock, their outputs are pinned by
/// `test/derivation_vectors_test.dart`.
///
/// Reached through [Deriver], a namespace: `Deriver.bitcoin.xpub(…)`,
/// `Deriver.bip85.hex(…)`. Each sub-deriver owns exactly one foreign
/// library, so "where does bdk get called" is one file.
///
/// **Adding a deriver:** `<source>_deriver.dart` here, a `const` class
/// with instance methods taking `SecretMaterial` — or `MnemonicMaterial`
/// when the library needs words, so the refusal is in the type — exported
/// below, and a `static const` on [Deriver].
library;

import 'package:secrets/src/crypto/derivers/bip85_deriver.dart';
import 'package:secrets/src/crypto/derivers/bitcoin_deriver.dart';
import 'package:secrets/src/crypto/derivers/identity_deriver.dart';
import 'package:secrets/src/crypto/derivers/boltz_deriver.dart';
import 'package:secrets/src/crypto/derivers/liquid_deriver.dart';

export 'bip85_deriver.dart' show Bip85Deriver;
export 'bitcoin_deriver.dart' show BitcoinDeriver, Descriptors;
export 'identity_deriver.dart' show IdentityDeriver;
export 'boltz_deriver.dart' show BoltzDeriver;
export 'liquid_deriver.dart' show LiquidDeriver;

/// The derivers, by source. Not instantiable; a namespace.
abstract final class Deriver {
  /// BIP32 root, account xpubs, bdk descriptors.
  static const bitcoin = BitcoinDeriver();

  /// Confidential descriptor, through lwk.
  static const liquid = LiquidDeriver();

  /// BIP85 children.
  static const bip85 = Bip85Deriver();

  /// Words → seed → master fingerprint.
  static const identity = IdentityDeriver();

  /// The swap key, through boltz.
  static const boltz = BoltzDeriver();
}
