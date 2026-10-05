import 'dart:typed_data';

import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/bip352_deriver.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

/// The shape of bwk's stateless silent payments signer,
/// `signSilentPaymentPsbt`.
typedef LendSilentPaymentKeys =
    Future<Uint8List> Function({
      required List<int> psbt,
      required List<int> bSpend,
      String? taprootAccountXprv,
    });

/// Signs the unsigned PSBTv2 of a silent payments spend for an account that
/// holds no spend authority. Reached as `Signer.silentPayment`.
///
/// The account is the caller's and never reaches this package: bwk keeps it
/// alive between calls to scan and simulate, built from the scan credential
/// alone, and its `preparePsbt` hands the caller the PSBT to sign. To sign,
/// this signer derives the BIP352 spend key and the BIP86 taproot account key
/// and lends them to bwk's `signSilentPaymentPsbt` for one call: a free
/// function that holds nothing, completes the silent payment outputs (BIP375
/// shares, DLEQ proofs, output scripts), signs every input and wipes its own
/// copies. The words, the seed and the master key never reach bwk.
///
/// Erasure is best effort. The spend key crosses as a [Uint8List] this signer
/// built and zeroes once the call returns, on every path; the FFI copies it
/// into Rust on the way in, out of reach. The account xprv is a Dart string,
/// which nothing can overwrite: it stays in the heap until the garbage
/// collector reclaims it. See doc/design.md, § Silent payments.
final class SilentPaymentSigner {
  @internal
  const SilentPaymentSigner();

  /// The signed PSBTv2 for [psbt], the unsigned one a simulation carries.
  ///
  /// [lendTo] is bwk's signer; tests substitute an observer through the
  /// package's own `src/` import, which no other package can reach.
  ///
  /// Throws [SilentPaymentSigningFailed] when bwk refuses: an input neither
  /// key owns, an unsupported script or sighash, a PSBT already signed.
  /// Whether the signed PSBT still describes what the user confirmed is
  /// decided after this call, by the account's `finalize`.
  Future<Uint8List> signPsbt(
    Mnemonic secret,
    Uint8List psbt, {
    required BitcoinNetwork network,
    @visibleForTesting LendSilentPaymentKeys lendTo = bwk.signSilentPaymentPsbt,
  }) async {
    final keys = const Bip352Deriver().spendKeys(secret, network: network);
    final spend = keys.spendPrivateKey;
    try {
      return await lendTo(
        psbt: psbt,
        bSpend: spend,
        taprootAccountXprv: keys.taprootAccountXprv,
      );
    } on Exception {
      // bwk's reason describes the PSBT it refused; nothing of it travels.
      throw const SilentPaymentSigningFailed();
    } finally {
      spend.fillRange(0, spend.length, 0);
    }
  }
}
