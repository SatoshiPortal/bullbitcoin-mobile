import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/bitcoin_deriver.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

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
/// callee holds its own reference and disposing ours is safe. No handle
/// outlives a call: payjoin signs its proposal through [signPsbt] too.
final class BitcoinSigner {
  /// bdk's gap limit when deriving addresses to recognise its own inputs.
  /// Matches `BdkFacade`, so a PSBT this signer accepts is the one the
  /// app's wallet would have accepted.
  static const _lookahead = 25;

  @internal
  const BitcoinSigner();

  /// Signs one PSBT and frees everything it built.
  Future<String> signPsbt(
    Mnemonic secret, {
    required String psbt,
    required ScriptType scriptType,
    required BitcoinNetwork network,
    int accountIndex = 0,
  }) async {
    final wallet = _wallet(
      secret,
      scriptType: scriptType,
      network: network,
      accountIndex: accountIndex,
    );
    try {
      return _sign(wallet, psbt);
    } finally {
      wallet.dispose();
    }
  }

  /// Signs only the supplied key occurrences; public policy validation stays with the wallet.
  String signDescriptorPsbt(
    SecretMaterial secret, {
    required String psbt,
    required String descriptor,
    required BitcoinNetwork network,
    required List<DescriptorSigningKey> keys,
    String? passphrase,
    bool signWithTapInternalKey = false,
  }) {
    final releases = <void Function()>[];
    var failed = false;
    try {
      if (keys.isEmpty) throw const PsbtSigningFailed();
      final material = const BitcoinDeriver().withPassphrase(
        secret,
        passphrase,
      );
      final kind = network.isMainnet
          ? bdk.NetworkKind.main
          : bdk.NetworkKind.test;
      final publicDescriptor = bdk.Descriptor(
        descriptor: descriptor,
        networkKind: kind,
      );
      releases.add(publicDescriptor.dispose);
      if (publicDescriptor.toString() !=
          publicDescriptor.toStringWithSecret()) {
        throw const PsbtSigningFailed();
      }
      publicDescriptor.sanityCheck();
      final branches = publicDescriptor.toSingleDescriptors();
      releases.addAll(branches.map((branch) => branch.dispose));
      if (!publicDescriptor.isMultipath() || branches.length != 2) {
        throw const PsbtSigningFailed();
      }
      var privateDescriptor = descriptor.split('#').first;
      final root = bdk.DescriptorSecretKey.fromString(
        privateKey: const BitcoinDeriver().masterXprv(material, network),
      );
      releases.add(root.dispose);
      for (final selected in keys) {
        final account = const BitcoinDeriver().account(
          material,
          derivationPath: selected.derivationPath,
          network: network,
        );
        final encoding = network.isMainnet ? XpubType.xpub : XpubType.tpub;
        if (!_isPublicKey(selected.xpub, network) ||
            encoding.reencode(selected.xpub) != account.xpub) {
          throw const PsbtSigningFailed();
        }
        final expression = RegExp(
          r'^(\[[0-9a-fA-F]{8}(?:/[0-9]+[h\x27]?)*\])?'
          r'((?:xpub|tpub|ypub|zpub|upub|vpub)[1-9A-HJ-NP-Za-km-z]+)'
          r'((?:/[^,(){}]+)?)$',
        ).firstMatch(selected.publicExpression);
        if (expression == null) throw const PsbtSigningFailed();
        final publicKey = expression.group(2);
        final suffix = expression.group(3);
        if (publicKey == null ||
            suffix == null ||
            !_isPublicKey(publicKey, network) ||
            encoding.reencode(publicKey) != account.xpub) {
          throw const PsbtSigningFailed();
        }
        final occurrence = RegExp(
          '${RegExp.escape(selected.publicExpression)}(?=[,)])',
        ).firstMatch(privateDescriptor);
        if (occurrence == null) throw const PsbtSigningFailed();
        final path = bdk.DerivationPath(path: account.derivationPath);
        releases.add(path.dispose);
        final accountKey = root.derive(path: path);
        releases.add(accountKey.dispose);
        var privateExpression = accountKey.toString();
        if (expression.group(1) == null) {
          privateExpression = privateExpression.substring(
            privateExpression.indexOf(']') + 1,
          );
        }
        privateDescriptor = privateDescriptor.replaceRange(
          occurrence.start,
          occurrence.end,
          '$privateExpression$suffix',
        );
      }
      // BIP389 selects every tuple's first member for receive and second for change.
      final tuple = RegExp(r'<([0-9]+);([0-9]+)>');
      String branch(int member) =>
          privateDescriptor.replaceAllMapped(tuple, (match) {
            final value = match.group(member);
            if (value == null) throw const PsbtSigningFailed();
            return value;
          });
      final external = bdk.Descriptor(descriptor: branch(1), networkKind: kind);
      releases.add(external.dispose);
      final internal = bdk.Descriptor(descriptor: branch(2), networkKind: kind);
      releases.add(internal.dispose);
      final persister = bdk.Persister.newInMemory();
      releases.add(persister.dispose);
      final wallet = bdk.Wallet(
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
      releases.add(wallet.dispose);
      final parsed = bdk.Psbt(psbtBase64: psbt);
      releases.add(parsed.dispose);
      wallet.sign(
        psbt: parsed,
        signOptions: bdk.SignOptions(
          trustWitnessUtxo: true,
          assumeHeight: null,
          allowAllSighashes: false,
          tryFinalize: false,
          signWithTapInternalKey: signWithTapInternalKey,
          allowGrinding: true,
        ),
      );
      return parsed.serialize();
    } catch (e) {
      failed = true;
      // FFI parse errors may contain the private descriptor being parsed.
      if (e is Error || e is PassphraseUnsupported) rethrow;
      throw const PsbtSigningFailed();
    } finally {
      final releaseFailure = disposeAll(releases.reversed.toList());
      if (releaseFailure != null) {
        if (!failed) throw const PsbtSigningFailed();
        log.warning('Descriptor signing handle release failed');
      }
    }
  }

  static bool _isPublicKey(String key, BitcoinNetwork network) =>
      (network.isMainnet
              ? const ['xpub', 'ypub', 'zpub']
              : const ['tpub', 'upub', 'vpub'])
          .any(key.startsWith);

  /// bdk's exceptions do not leave as they are: bdk's parse error quotes
  /// its input, so every failure becomes the package's own.
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
      // The free is a rustCall too: a failure here is translated rather
      // than surfaced with a Rust message attached.
      try {
        parsed.dispose();
      } on Exception {
        throw const PsbtSigningFailed();
      }
    }
  }

  /// A signing-only bdk wallet, persisted nowhere.
  ///
  /// Built from the language-aware BIP39 seed via the Dart master xprv. The account path
  /// matches the public descriptors and xpub derivation.
  ///
  /// The secret key and the two descriptors are freed here:
  /// the wallet holds its own references, and these would otherwise keep
  /// an xprv in native memory for as long as the wallet.
  bdk.Wallet _wallet(
    Mnemonic secret, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
    required int accountIndex,
  }) {
    // Every handle is declared before the try and freed in the finally, so a
    // throw from any allocation still releases the ones already made. The
    // previous shape opened the try around the Wallet call alone, with five
    // allocations above it — and Persister.newInMemory() is a throwing
    // constructor sitting last among them, so a failure there stranded the
    // xprv-bearing secretKey and both private descriptors until the garbage
    // collector happened to run their finalizers. That is precisely the
    // "eventually" this class's dispose discipline exists to avoid.
    bdk.DescriptorSecretKey? secretKey;
    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    bdk.Persister? persister;
    bdk.Wallet? wallet;
    Object? bodyFailure;
    try {
      final key = secretKey = bdk.DescriptorSecretKey.fromString(
        privateKey: const BitcoinDeriver().masterXprv(secret, network),
      );

      bdk.Descriptor keychain(bdk.KeychainKind kind) =>
          BitcoinDeriver.privateDescriptor(
            key,
            scriptType: scriptType,
            network: network,
            accountIndex: accountIndex,
            keychain: kind,
          );

      external = keychain(bdk.KeychainKind.external_);
      internal = keychain(bdk.KeychainKind.internal);
      // Nothing to keep: this wallet exists for the length of one signature
      // and leaves no file behind.
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
