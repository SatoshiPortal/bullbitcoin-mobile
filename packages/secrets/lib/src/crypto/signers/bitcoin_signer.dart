import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/crypto/signers/signers.dart';
import 'package:secrets/src/domain/domain.dart';

/// Signs a base64 PSBT and returns the signed result.
///
/// Synchronous on purpose: bdk's `sign` and `serialize` are, and the Payjoin receiver hands this callback to a native finalisation step that cannot suspend. A closure that could `await` here would have nowhere to do so.
typedef PsbtSigner = String Function(String psbt);

/// Bitcoin signing through bdk. Reached as `Signer.bitcoin`.
///
/// Builds a wallet the signer owns and throws away. It never touches the
/// app's wallet databases: signing needs the keys and the descriptors,
/// not the transaction history.
///
/// **Every bdk handle this class creates is freed before the call
/// returns.** bdk is UniFFI-generated: each handle owns native memory and
/// carries a `Finalizer`, so nothing leaks — but a finalizer runs when
/// the GC gets to it, and until then an xprv and a private descriptor sit
/// in native memory. `dispose()` is what makes "secrets are ephemeral"
/// true here rather than eventually. `lower()` clones the pointer, so the
/// callee holds its own reference and disposing ours is safe.
///
/// The one handle that outlives a call is the wallet behind
/// [psbtSigner] — see there.
final class BitcoinSigner {
  /// bdk's gap limit when deriving addresses to recognise its own inputs.
  /// Matches `BdkFacade`, so a PSBT this signer accepts is the one the
  /// app's wallet would have accepted.
  static const _lookahead = 25;

  const BitcoinSigner();

  /// Signs one PSBT and frees everything it built.
  ///
  /// The normal path. [psbtSigner] exists for payjoin, which cannot work
  /// this way.
  Future<String> signPsbt(
    MnemonicMaterial secret, {
    required String psbt,
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) async {
    final wallet = _wallet(secret, scriptType: scriptType, network: network);
    try {
      return _sign(wallet, psbt);
    } finally {
      wallet.dispose();
    }
  }

  /// A closure that signs PSBTs for [secret].
  ///
  /// The wallet is built here and captured by the closure, so a caller
  /// that signs many transactions pays the construction once. The
  /// mnemonic never crosses the returned boundary.
  ///
  /// ⚠️ **The wallet lives as long as the closure**, and it holds private
  /// descriptors in native memory: bdk offers no way to sign repeatedly
  /// without one. Nothing leaks — the handle's finalizer frees it once the
  /// closure is unreachable — but the caller decides how long that is.
  /// Payjoin is the only caller, and it drops the signer with the session.
  Future<PsbtSigner> psbtSigner(
    MnemonicMaterial secret, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) async {
    final wallet = _wallet(secret, scriptType: scriptType, network: network);
    return (String psbt) => _sign(wallet, psbt);
  }

  /// bdk's exceptions do not leave: the closure returned by [psbtSigner]
  /// runs outside any boundary, and bdk's parse error quotes its input.
  static String _sign(bdk.Wallet wallet, String psbt) {
    final bdk.Psbt parsed;
    try {
      parsed = bdk.Psbt(psbtBase64: psbt);
    } on Exception {
      throw const PsbtSigningFailed();
    }
    try {
      final isFinalized = wallet.sign(psbt: parsed, signOptions: _signOptions);
      // Not an error on its own: a payjoin proposal still carries the
      // other party's unsigned inputs, so bdk's whole-PSBT finalization
      // check is false there by protocol design.
      log.fine('Signed PSBT finalized: $isFinalized');
      return parsed.serialize();
    } on Exception {
      throw const PsbtSigningFailed();
    } finally {
      // The free is a rustCall too, and from `psbtSigner`'s closure this runs
      // outside any boundary: a failure here is translated rather than handed
      // to the payjoin engine with a Rust message attached.
      try {
        parsed.dispose();
      } on Exception {
        throw const PsbtSigningFailed();
      }
    }
  }

  /// A signing-only bdk wallet, persisted nowhere.
  ///
  /// Built from the BIP39 words rather than from the master xprv, which
  /// mirrors `BdkFacade.createPrivateWallet` exactly. The two paths
  /// should produce identical keys, but a refactor is the wrong place to
  /// find out otherwise: signatures must come out of the same
  /// construction they came out of before.
  ///
  /// The mnemonic, the secret key and the two descriptors are freed here:
  /// the wallet holds its own references, and these would otherwise keep
  /// an xprv in native memory for as long as the wallet.
  bdk.Wallet _wallet(
    MnemonicMaterial secret, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
  }) {
    final networkKind = network.isMainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;

    // Every handle is declared before the try and freed in the finally, so a
    // throw from any allocation still releases the ones already made. The
    // previous shape opened the try around the Wallet call alone, with five
    // allocations above it — and Persister.newInMemory() is a throwing
    // constructor sitting last among them, so a failure there stranded the
    // xprv-bearing secretKey and both private descriptors until the garbage
    // collector happened to run their finalizers. That is precisely the
    // "eventually" this class's dispose discipline exists to avoid.
    bdk.Mnemonic? mnemonic;
    bdk.DescriptorSecretKey? secretKey;
    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    bdk.Persister? persister;
    bdk.Wallet? wallet;
    Object? bodyFailure;
    try {
      mnemonic = bdk.Mnemonic.fromString(mnemonic: mnemonicSentence(secret));
      secretKey = bdk.DescriptorSecretKey(
        networkKind: networkKind,
        mnemonic: mnemonic,
        // Empty and absent are the same passphrase to BIP39, but the app
        // has always passed `null` for absent. Keep it.
        password: secret.passphrase.isNotEmpty ? secret.passphrase : null,
      );

      bdk.Descriptor keychain(bdk.KeychainKind kind) => switch (scriptType) {
        ScriptType.bip84 => bdk.Descriptor.newBip84(
          secretKey: secretKey!,
          keychainKind: kind,
          networkKind: networkKind,
        ),
        ScriptType.bip49 => bdk.Descriptor.newBip49(
          secretKey: secretKey!,
          keychainKind: kind,
          networkKind: networkKind,
        ),
        ScriptType.bip44 => bdk.Descriptor.newBip44(
          secretKey: secretKey!,
          keychainKind: kind,
          networkKind: networkKind,
        ),
      };

      external = keychain(bdk.KeychainKind.external_);
      internal = keychain(bdk.KeychainKind.internal);
      // Nothing to keep: this wallet exists for the length of one signing
      // session and leaves no file behind.
      persister = bdk.Persister.newInMemory();
      wallet = bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: switch (network) {
          BitcoinNetwork.mainnet => bdk.Network.bitcoin,
          BitcoinNetwork.testnet => bdk.Network.testnet,
          BitcoinNetwork.signet => bdk.Network.signet,
          BitcoinNetwork.regtest => bdk.Network.regtest,
        },
        persister: persister,
        lookahead: _lookahead,
      );
      return wallet;
    } catch (e) {
      bodyFailure = e;
      rethrow;
    } finally {
      // Each dispose() is a rustCall and can throw. Freed one at a time, so
      // a failure on one handle never skips the others — a plain sequence
      // would have leaked every handle after the first throw. Key-bearing
      // handles go first. If any release failed, the wallet built above
      // holds both private descriptors and would otherwise leave this
      // method with nobody left to free it: release it too. Then: if the
      // body had already failed, that is the cause worth surfacing and the
      // release failure is logged beside it — throwing here would replace
      // the allocation error with the cleanup error. Otherwise surface it,
      // rather than hand out a wallet behind a broken cleanup.
      final failure = disposeAll(
        [
          secretKey?.dispose,
          mnemonic?.dispose,
          external?.dispose,
          internal?.dispose,
          persister?.dispose,
        ].nonNulls.toList(),
      );
      if (failure != null) {
        disposeAll([wallet?.dispose].nonNulls.toList());
        if (bodyFailure != null) {
          log.warning(
            'bdk handle release failed after a failed wallet build: '
            '${describeSafely(failure.error)}',
          );
        } else {
          Error.throwWithStackTrace(failure.error, failure.stackTrace);
        }
      }
    }
  }

  /// Runs every release, attempting each even after one throws.
  /// Returns the first failure, or null when all released cleanly.
  ///
  /// Tear-offs, not handles: `secretKey.dispose` is checked by the compiler,
  /// where `(handle as dynamic).dispose()` would have turned a renamed bdk
  /// method into a runtime failure of every signature (AGENTS.md, rule 15).
  @visibleForTesting
  static ({Object error, StackTrace stackTrace})? disposeAll(
    List<void Function()> releases,
  ) {
    ({Object error, StackTrace stackTrace})? first;
    for (final release in releases) {
      try {
        release();
      } catch (e, st) {
        first ??= (error: e, stackTrace: st);
      }
    }
    return first;
  }

  /// Mirrors `BdkWalletDatasource.signPsbt` exactly: a refactor must not
  /// change how signatures are produced.
  static final _signOptions = bdk.SignOptions(
    trustWitnessUtxo: true,
    assumeHeight: null,
    // The signer contributes its own inputs under the sighash the
    // transaction specifies; accepting any sighash would let a
    // counterparty choose one.
    allowAllSighashes: false,
    tryFinalize: true,
    signWithTapInternalKey: false,
    allowGrinding: true,
  );
}
