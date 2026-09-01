import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

/// Mnemonic signing material handed to a datasource for the length of one call.
///
/// Deliberately not a generated data model: value equality over a mnemonic
/// turns `==` into a guessing oracle, and a generated `toString` would put the
/// words into every exception, log line and collection dump (spec F14).
final class WalletSigningMaterial {
  final List<String> mnemonicWords;
  final String? passphrase;

  const WalletSigningMaterial({required this.mnemonicWords, this.passphrase});

  /// The space-joined form the BDK/LWK datasources take.
  String get mnemonic => mnemonicWords.join(' ');

  @override
  String toString() =>
      'WalletSigningMaterial(mnemonic: <redacted>, passphrase: <redacted>)';
}

/// The one place that decides where a wallet's private signing material comes
/// from, and the only thing outside [WalletUnlockSession] that touches it
/// (spec F13).
///
/// A passphrase wallet's material exists solely in the volatile session for as
/// long as the user keeps it loaded; every other wallet resolves from the
/// persistent seed store. Signing, address generation, wallet storage and
/// Payjoin all ask here instead of reading a global session, so locking is a
/// single fact rather than a check each of them has to remember to make.
final class WalletSigningMaterialResolver {
  final SeedDatasource _seedDatasource;
  final WalletUnlockSession _session;

  const WalletSigningMaterialResolver({
    required this._seedDatasource,
    required this._session,
  });

  Future<void> close() => _session.close();

  /// Emits whenever the loaded private capability changes, so the visible
  /// wallet catalog can follow it.
  Stream<void> get capabilityChanges => _session.changes;

  /// Whether private material for [walletId] can be resolved right now.
  ///
  /// Only a passphrase wallet can answer `false`: every other provenance keeps
  /// its seed in the persistent store.
  bool hasPrivateCapability({
    required WalletProvenance provenance,
    required String walletId,
  }) =>
      provenance != WalletProvenance.defaultSeedPassphrase ||
      _session.isUnlocked(walletId);

  /// Whether [walletId] is the wallet currently loaded in the private session.
  bool isPrivateCapabilityLoaded(String walletId) =>
      _session.isUnlocked(walletId);

  /// Throws [PassphraseWalletLockedException] when [walletId]'s private
  /// material is not available.
  void requirePrivateCapability({
    required WalletProvenance provenance,
    required String walletId,
  }) {
    if (!hasPrivateCapability(provenance: provenance, walletId: walletId)) {
      throw PassphraseWalletLockedException(walletId);
    }
  }

  int beginPrivateCapabilityMount() => _session.beginMount();

  void cancelPrivateCapabilityMount() => _session.cancelMount();

  /// Takes ownership of [seed] only if this is still the current mount.
  bool loadPrivateCapabilityIfCurrent({
    required int generation,
    required String walletId,
    required MnemonicSeed seed,
  }) => _session.unlockIfCurrent(
    generation: generation,
    walletId: walletId,
    seed: seed,
  );

  /// Clears the loaded private material. Returns whether anything was loaded.
  bool clearPrivateCapability() => _session.lock();

  /// [clearPrivateCapability] for the app losing the foreground, which also
  /// records the return-to-Passphrase request collected by
  /// [takePendingLockNavigationRequest] on resume (decision 5).
  bool clearPrivateCapabilityForBackground() => _session.lockForBackground();

  /// Consumes the navigation request published by the last background lock.
  bool takePendingLockNavigationRequest() =>
      _session.takePendingResumeNavigation();

  /// Resolves the signing material for [metadata].
  ///
  /// Throws [PassphraseWalletLockedException] when a passphrase wallet is
  /// locked, and [StateError] when a wallet with no local mnemonic is asked to
  /// sign.
  Future<WalletSigningMaterial> resolve(WalletMetadataModel metadata) async {
    if (metadata.provenance == WalletProvenance.defaultSeedPassphrase) {
      final seed = _session.seedFor(metadata.id);
      return WalletSigningMaterial(
        mnemonicWords: seed.mnemonicWords,
        passphrase: seed.passphrase,
      );
    }
    final seed = await _seedDatasource.get(metadata.masterFingerprint);
    if (seed is! MnemonicSeedModel) {
      throw StateError('Wallet ${metadata.id} requires a local mnemonic');
    }
    return WalletSigningMaterial(
      mnemonicWords: seed.mnemonicWords,
      passphrase: seed.passphrase,
    );
  }
}
