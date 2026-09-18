import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/crypto/signers/signers.dart';
import 'package:secrets/src/domain/domain.dart';

/// Liquid signing through lwk. Reached as `Signer.liquid`.
///
/// One-shot, unlike [BitcoinSigner]: lwk gives no reason to hold a
/// wallet open — `signTx` takes the mnemonic again at call time, so the
/// wallet built by `Wallet.init` holds no key worth reusing.
///
/// The lwk wallet is `dispose()`d before the call returns: it is a
/// flutter_rust_bridge opaque, so its `Arc` would otherwise be released
/// whenever the GC got to it. The scratch directory goes the same way —
/// see [signPset].
///
/// ⚠️ A passphrase is ignored. lwk's signer hard-codes `to_seed("")`
/// and no layer of the binding takes one. See the README, § Passphrase.
final class LiquidSigner {
  const LiquidSigner();

  /// Signs one PSET and returns it.
  ///
  /// [scratchDirectory] is where lwk may write its scratch wallet cache
  /// for the length of this call. lwk has no in-memory persister —
  /// `Wallet.init` requires a path — so the host supplies a directory
  /// rather than this package reaching for `path_provider`. It is a
  /// parameter of the operation, not of the signer: each call creates
  /// and removes its own directory beneath it, and keeping this type
  /// field-free is what lets it sit on the [Signer] namespace like the
  /// others. It goes away the day lwk-dart binds `SwSigner` directly.
  Future<String> signPset(
    MnemonicMaterial secret, {
    required String pset,
    required LiquidNetwork network,
    required Future<String> Function() scratchDirectory,
  }) async {
    final mnemonic = mnemonicSentence(secret);
    final lwkNetwork = _network(network);

    // A fresh directory per signature, removed below.
    //
    // lwk has no in-memory persister, so a database gets created whether
    // we want one or not. Keeping it would leave a confidential
    // descriptor on disk in an unencrypted file, outside the keystore
    // this package exists to keep things inside — and name it after a
    // wallet fingerprint while we were at it. A temporary directory
    // costs one wallet construction per signature and leaves nothing.
    final parent = Directory(await scratchDirectory());
    // A process killed mid-signature leaves its directory behind, and the
    // parent's own purge policy is the OS's, not ours. Sweep stale siblings
    // before adding one: anything older than an hour cannot be a signature
    // still in flight, so this races with nothing. Best-effort — a sweep
    // that fails must not fail the signature.
    await sweepStale(parent);
    final scratch = await parent.createTemp('lwk_sign_');

    lwk.Wallet? wallet;
    try {
      wallet = await lwk.Wallet.init(
        network: lwkNetwork,
        dbpath: scratch.path,
        descriptor: await lwk.Descriptor.newConfidential(
          network: lwkNetwork,
          mnemonic: mnemonic,
        ),
      );
      return await wallet.signTx(
        network: lwkNetwork,
        pset: pset,
        mnemonic: mnemonic,
      );
    } on lwk.LwkError {
      // `e.msg` is lwk's text and is not logged: the input is a PSET and a mnemonic, and no rule keeps a foreign message from quoting either. The boundary reports the type.
      throw const LiquidSigningFailed();
    } finally {
      // An FRB opaque holding the wallet's `Arc`; `Descriptor` is a plain
      // value and has no handle to release.
      wallet?.dispose();
      try {
        await scratch.delete(recursive: true);
      } catch (e) {
        // A leftover only happens if deletion itself fails; a hard crash
        // mid-signature can also leave one. Worth knowing about, not
        // worth failing a signature over.
        // Type and errno only — the one foreign message this file used to
        // interpolate. It is a dart:io error on a host-chosen path, never
        // material, but the package's rule is that no foreign text travels.
        log.warning(
          'Could not remove lwk scratch directory: ${e.runtimeType} '
          '${e is FileSystemException ? (e.osError?.errorCode ?? '') : ''}',
        );
      }
    }
  }

  static lwk.LiquidNetwork _network(LiquidNetwork network) => switch (network) {
    LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
    LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
    // Elements regtest is a different chain; lwk has no variant for
    // it, and signing on testnet's would produce a signature for the
    // wrong chain. See `SecretDeriver.liquidDescriptor`.
    LiquidNetwork.regtest => throw const UnsupportedLiquidNetwork(
      'lwk cannot express Liquid regtest',
    ),
  };

  static const _stalePrefix = 'lwk_sign_';

  /// Signatures are interactive and finish in seconds. Ten minutes is a wide
  /// margin for one still running — the one thing the sweep must never
  /// delete — and no longer than a leftover deserves to live.
  static const _staleAfter = Duration(minutes: 10);

  /// Sweeps the parent of the host-supplied scratch directory.
  ///
  /// Called by `Secrets` at construction, so a leftover of a signature the
  /// process did not survive does not wait for the next Liquid signature,
  /// which may never come. Best effort: a failure is logged by type and
  /// errno, never by path.
  Future<void> sweepScratch(Future<String> Function() scratchDirectory) async {
    try {
      await sweepStale(Directory(await scratchDirectory()));
    } on Exception catch (e) {
      log.warning('Could not sweep lwk scratch: ${e.runtimeType}');
    }
  }

  /// Removes leftover `lwk_sign_*` directories older than [_staleAfter].
  ///
  /// One entry's failure costs that entry only, not the rest of the sweep.
  /// An mtime in the future is a clock that moved, not a directory that is
  /// old, and is left alone.
  Future<void> sweepStale(Directory parent) async {
    try {
      if (!await parent.exists()) return;
      final now = DateTime.now();
      final cutoff = now.subtract(_staleAfter);
      await for (final entry in parent.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (!name.startsWith(_stalePrefix)) continue;
        try {
          final modified = (await entry.stat()).modified;
          if (modified.isAfter(now) || modified.isAfter(cutoff)) continue;
          await entry.delete(recursive: true);
        } on FileSystemException catch (e) {
          // Type and errno only: the path is the host's, the value is nobody's.
          log.warning(
            'Could not sweep one stale lwk scratch: ${e.runtimeType} '
            '${e.osError?.errorCode ?? ''}',
          );
        }
      }
    } on FileSystemException catch (e) {
      log.warning(
        'Could not list lwk scratch: ${e.runtimeType} '
        '${e.osError?.errorCode ?? ''}',
      );
    }
  }
}
