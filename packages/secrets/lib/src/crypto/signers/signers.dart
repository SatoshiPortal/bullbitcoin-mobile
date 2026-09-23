/// The signers this package holds, one per chain, and the one rule they
/// share.
///
/// A signer here is pure: key material and a payload in, a signature
/// out. No network, no persistence, no fields — the one host resource
/// any of them needs, lwk's scratch directory, is a parameter of the
/// call, not of the object. Each lives in its own file and takes
/// [MnemonicMaterial] — never a bare `SecretMaterial` — so that the
/// question "can this secret sign?" is answered by the type before any
/// key is derived.
///
/// Reached through [Signer], a namespace: `Signer.bitcoin.signPsbt(…)`,
/// `Signer.liquid.signPset(…)` — the same shape as `Deriver` and
/// `Backup`.
///
/// There is deliberately no common interface: Bitcoin needs a script
/// type and Liquid does not, and the two networks are different enums. Nothing calls a
/// signer polymorphically — `Secret.signPsbt` knows it wants Bitcoin —
/// so an interface would document a shape no code relies on.
///
/// **Adding a signer** (Ark is the expected next one):
///
///  1. `<chain>_signer.dart` in this directory, exported from this file
///     with an explicit `show`.
///  2. Take [MnemonicMaterial]; turn it into a sentence with
///     [mnemonicSentence] and nothing else, so the seed-only refusal is
///     the same everywhere.
///  3. A `static const` on [Signer], and the operation itself on
///     `Secret` — flat, beside the others. If the library needs a host
///     resource, it is a parameter of the operation, never a field.
///  4. Nothing in `api/` may import the chain library: the import
///     invariant test enforces it. The signer is where the library lives.
library;

import 'package:secrets/src/crypto/signers/bitcoin_signer.dart';
import 'package:secrets/src/crypto/signers/liquid_signer.dart';
import 'package:secrets/src/domain/domain.dart';

export 'bitcoin_signer.dart' show BitcoinSigner;
export 'liquid_signer.dart' show LiquidSigner;

/// The BIP39 sentence every signer signs from.
///
/// One place, so the rule cannot drift between chains: the libraries
/// take the words as one space-joined string, and a seed-only secret —
/// `SeedMaterial`, which exists only to read entries that predate the
/// current format — has no words to give. Callers reach this only with
/// [MnemonicMaterial]; the switch is here for the day a signer is handed
/// the base type by mistake.
String mnemonicSentence(SecretMaterial secret) => switch (secret) {
  MnemonicMaterial(:final words) => words.join(' '),
  SeedMaterial() => throw ArgumentError.value(
    secret.info.kind,
    'secret',
    'signing derives from BIP39 words',
  ),
};

/// The signers, by chain. Not instantiable; a namespace.
abstract final class Signer {
  /// PSBT, through bdk.
  static const bitcoin = BitcoinSigner();

  /// PSET, through lwk.
  static const liquid = LiquidSigner();
}
