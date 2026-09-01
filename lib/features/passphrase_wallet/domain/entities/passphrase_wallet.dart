import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

final class PassphraseWalletRecord {
  final String walletId;
  final Fingerprint parentFingerprint;
  final Fingerprint seedFingerprint;
  final Network network;
  final String descriptor;
  final DateTime createdAt;
  final String? label;
  final String? hint;

  const PassphraseWalletRecord({
    required this.walletId,
    required this.parentFingerprint,
    required this.seedFingerprint,
    required this.network,
    required this.descriptor,
    required this.createdAt,
    this.label,
    this.hint,
  });

  PassphraseWalletRecord withHint(String? value) => PassphraseWalletRecord(
    walletId: walletId,
    parentFingerprint: parentFingerprint,
    seedFingerprint: seedFingerprint,
    network: network,
    descriptor: descriptor,
    createdAt: createdAt,
    label: label,
    hint: value,
  );
}

final class PassphraseWalletBalance {
  final BigInt satoshis;

  const PassphraseWalletBalance({required this.satoshis});

  @override
  bool operator ==(Object other) =>
      other is PassphraseWalletBalance && other.satoshis == satoshis;

  @override
  int get hashCode => satoshis.hashCode;
}

/// The wallet one entered passphrase would open, holding the private material
/// derived for it until somebody takes ownership of it or clears it.
///
/// Exactly one of [release] and [clear] must run on every path (spec 20.3):
/// [release] when the wallet session has taken the material and must keep it
/// alive, [clear] everywhere else. Both are idempotent, so a cancel path may
/// clear a candidate that was already released without zeroing a loaded
/// wallet's seed.
final class PassphraseWalletCandidate {
  final PassphraseWalletRecord record;
  MnemonicSeed? _material;

  PassphraseWalletCandidate({required this.record, required MnemonicSeed seed})
    : _material = seed;

  /// The material to hand to its new owner.
  ///
  /// Throws [StateError] once the candidate has been released or cleared: a
  /// second use would be reading material this object no longer accounts for.
  MnemonicSeed get seed {
    final seed = _material;
    if (seed == null) {
      throw StateError('Passphrase candidate material is no longer held');
    }
    return seed;
  }

  bool get isHeld => _material != null;

  /// Gives up the material without destroying it, because the wallet's private
  /// session now owns it.
  void release() => _material = null;

  /// Zeroes any material still held. Safe to call more than once, and after
  /// [release].
  void clear() {
    final seed = _material;
    _material = null;
    seed?.bytes.fillRange(0, seed.bytes.length, 0);
  }

  @override
  String toString() => 'PassphraseWalletCandidate(<redacted>)';
}

final class PassphraseWalletPreparation {
  final PassphraseWalletCandidate candidate;
  final PassphraseWalletRecord? knownWallet;
  final bool hasHistory;

  const PassphraseWalletPreparation({
    required this.candidate,
    required this.knownWallet,
    required this.hasHistory,
  });

  bool get isKnown => knownWallet != null;

  void clear() => candidate.clear();

  @override
  String toString() => 'PassphraseWalletPreparation(<redacted>)';
}

enum PassphraseWalletOpenStatus { opened, savedButNotOpened }

/// Whether a metadata edit reached both the manifest and the mounted wallet.
///
/// The manifest is canonical (decision 2), so a projection that could not be
/// refreshed is not a lost edit — it is a label the wallet shows again after
/// its next mount.
enum PassphraseWalletMetadataStatus { updated, savedRemountNeeded }
