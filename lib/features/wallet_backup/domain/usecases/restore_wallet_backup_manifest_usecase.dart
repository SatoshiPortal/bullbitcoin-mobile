import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';

typedef MatchesSeedDerivedRecoveryIdentity =
    Future<bool> Function({
      required String walletId,
      required String seedFingerprint,
      required Network network,
      required ScriptType scriptType,
      required WalletProvenance provenance,
      required String derivationPath,
      required bool? seedPassphraseUsed,
    });

class RestoreWalletBackupManifestUsecase {
  final MatchesSeedDerivedRecoveryIdentity _matchesWallet;
  final KeychainManifestFacade _manifest;
  final DateTime Function() _nowUtc;

  const RestoreWalletBackupManifestUsecase(
    this._matchesWallet,
    this._manifest, {
    this._nowUtc = _systemNowUtc,
  });

  Future<WalletBackupManifestRestoreResult> execute(
    KeychainManifest manifest, {
    DateTime? deadline,
  }) async {
    var restored = 0;
    var failed = 0;
    // Wallet records are applied in one pass so the conflict policy sees the
    // whole snapshot, and so a half-applied inventory cannot be committed.
    final admitted = <KeychainManifestEntry>[];

    for (final entry in manifest.entries) {
      if (_expired(deadline)) {
        failed += entry.materializations.length;
        continue;
      }
      if (entry.derivationKind == KeychainManifestDerivationKind.bip32) {
        final wallet = entry.materializations.single as KeychainManifestWallet;
        if (wallet.provenance == WalletProvenance.defaultSeed) {
          final matchesRoot =
              wallet.childSeedFingerprint == manifest.parentFingerprint;
          final matchesWallet =
              matchesRoot &&
              await _matchesWallet(
                walletId: wallet.walletId,
                seedFingerprint: wallet.childSeedFingerprint.hex,
                network: wallet.network,
                scriptType: wallet.scriptType,
                provenance: wallet.provenance,
                derivationPath: entry.derivationPath,
                seedPassphraseUsed: wallet.seedPassphraseUsed,
              );
          if (!matchesWallet) {
            failed++;
            continue;
          }
        } else if (wallet.provenance != WalletProvenance.importedMnemonic &&
            wallet.provenance != WalletProvenance.defaultSeedPassphrase) {
          failed++;
          continue;
        }
        admitted.add(entry);
        continue;
      }

      // Product-wallet materialization belongs to the product feature that
      // owns its creation ceremony. Until that feature is present, report the
      // wallet as unrestored instead of silently claiming complete recovery.
      failed += entry.materializations
          .whereType<KeychainManifestWallet>()
          .length;

      for (final key
          in entry.materializations.whereType<KeychainManifestNostrKey>()) {
        if (_expired(deadline)) {
          failed++;
          continue;
        }
        final reservationId = _reservationId(entry.derivationPath);
        if (reservationId == null) {
          failed++;
          continue;
        }
        final result = await _manifest.restoreNostrKey(
          reservationId: reservationId,
          parentFingerprint: manifest.parentFingerprint,
          derivationPath: entry.derivationPath,
          publicKeyHex: key.publicKeyHex,
          keyKind: key.keyKind,
          purpose: key.purpose,
          description: entry.description,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            key.createdAt * 1000,
            isUtc: true,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            key.updatedAt * 1000,
            isUtc: true,
          ),
        );
        if (result case Ok()) {
          restored++;
        } else {
          failed++;
        }
      }
    }

    if (admitted.isNotEmpty) {
      final applied = await _manifest.restoreSnapshot(
        KeychainManifest(
          parentFingerprint: manifest.parentFingerprint,
          generatedAt: manifest.generatedAt,
          entries: admitted,
        ),
      );
      switch (applied) {
        case Err():
          failed += admitted.length;
        case Ok(:final value):
          restored += value.restored;
          failed += value.conflicts.length;
      }
    }

    return WalletBackupManifestRestoreResult(
      restoredCount: restored,
      failedCount: failed,
    );
  }

  String? _reservationId(String path) {
    final reserved = Bip85Reservations.reservationByExactPath(path);
    if (reserved != null) return reserved.id;
    return Bip85Reservations.isNostrUserKeyPath(path)
        ? Bip85Reservations.nostrUserKeyReservationId
        : null;
  }

  bool _expired(DateTime? deadline) =>
      deadline != null && !_nowUtc().isBefore(deadline);
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
