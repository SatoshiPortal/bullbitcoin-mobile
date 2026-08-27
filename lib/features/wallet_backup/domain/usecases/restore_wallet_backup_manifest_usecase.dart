import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallets.dart';
import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';

class RestoreWalletBackupManifestUsecase {
  final PrepareDeterministicWalletsUsecase _prepareWallets;
  final KeychainManifestFacade _manifest;
  final DateTime Function() _nowUtc;

  const RestoreWalletBackupManifestUsecase(
    this._prepareWallets,
    this._manifest, {
    this._nowUtc = _systemNowUtc,
  });

  Future<WalletBackupManifestRestoreResult> execute(
    KeychainManifestImportPlan plan, {
    DateTime? deadline,
  }) async {
    var restored = 0;
    var failed = 0;
    final createdWalletIds = <String>[];

    for (final entry in plan.entries) {
      if (_expired(deadline)) {
        failed += entry.materializations.length;
        continue;
      }
      final reservation = Bip85Reservations.reservationById(
        entry.reservationId,
      );
      if (reservation?.purpose == Bip85ReservationPurpose.walletSeed) {
        final wallets = entry.materializations
            .whereType<KeychainManifestWallet>()
            .toList(growable: false);
        if (wallets.isEmpty) {
          failed += entry.materializations.length;
          continue;
        }
        final result = await _prepareWallets.execute(
          DeterministicWalletsRequest(
            bip85Index: reservation!.walletIndex,
            bip85Alias: reservation.deterministicAlias,
            environment: wallets.first.network.isMainnet
                ? Environment.mainnet
                : Environment.testnet,
            walletSpecs: [
              for (final wallet in wallets)
                DeterministicWalletSpec(
                  id: wallet.walletId,
                  network: wallet.network,
                  scriptType: wallet.scriptType,
                  isDefault: false,
                  sync: false,
                ),
            ],
          ),
        );
        switch (result) {
          case Err():
            failed += wallets.length;
          case Ok(:final value):
            if (!_matches(entry, wallets, value)) {
              if (await _prepareWallets.rollbackCreatedWallets(value)
                  case Err()) {
                failed += _remainingMaterializations(plan, entry);
                return WalletBackupManifestRestoreResult(
                  restoredCount: restored,
                  failedCount: failed,
                  createdWalletIds: List.unmodifiable(createdWalletIds),
                );
              }
              failed += wallets.length;
              continue;
            }
            final recorded = await _manifest.recordRecoveredDerivation(
              reservationId: entry.reservationId,
              parentFingerprint: plan.parentFingerprint,
              derivationPath: entry.bip85DerivationPath,
              wallets: [
                for (final wallet in wallets)
                  KeychainManifestWalletBinding(
                    walletId: wallet.walletId,
                    childSeedFingerprint: wallet.childSeedFingerprint,
                    network: wallet.network,
                    scriptType: wallet.scriptType,
                  ),
              ],
            );
            if (recorded case Err()) {
              if (await _prepareWallets.rollbackCreatedWallets(value)
                  case Err()) {
                failed += _remainingMaterializations(plan, entry);
                return WalletBackupManifestRestoreResult(
                  restoredCount: restored,
                  failedCount: failed,
                  createdWalletIds: List.unmodifiable(createdWalletIds),
                );
              }
              failed += wallets.length;
              continue;
            }
            restored += wallets.length;
            createdWalletIds.addAll(
              value.wallets
                  .where((wallet) => wallet.created)
                  .map((wallet) => wallet.walletId),
            );
        }
        continue;
      }

      for (final key
          in entry.materializations.whereType<KeychainManifestNostrKey>()) {
        if (_expired(deadline)) {
          failed++;
          continue;
        }
        final result = await _manifest.restoreNostrKey(
          reservationId: entry.reservationId,
          parentFingerprint: plan.parentFingerprint,
          derivationPath: entry.bip85DerivationPath,
          publicKeyHex: key.publicKeyHex,
          keyKind: key.keyKind,
          purpose: key.purpose,
          description: key.description,
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

    return WalletBackupManifestRestoreResult(
      restoredCount: restored,
      failedCount: failed,
      createdWalletIds: List.unmodifiable(createdWalletIds),
    );
  }

  bool _matches(
    KeychainManifestEntry entry,
    List<KeychainManifestWallet> expected,
    PreparedDeterministicWallets actual,
  ) {
    if (actual.parentFingerprint != entry.parentFingerprint.hex ||
        actual.derivationPath != entry.bip85DerivationPath ||
        actual.wallets.length != expected.length) {
      return false;
    }
    final bySpec = {for (final wallet in actual.wallets) wallet.specId: wallet};
    return expected.every((wallet) {
      final prepared = bySpec[wallet.walletId];
      return prepared != null &&
          prepared.walletId == wallet.walletId &&
          prepared.network == wallet.network &&
          prepared.scriptType == wallet.scriptType &&
          actual.childSeedFingerprint == wallet.childSeedFingerprint.hex;
    });
  }

  bool _expired(DateTime? deadline) =>
      deadline != null && !_nowUtc().isBefore(deadline);

  int _remainingMaterializations(
    KeychainManifestImportPlan plan,
    KeychainManifestEntry failedEntry,
  ) {
    final index = plan.entries.indexOf(failedEntry);
    return plan.entries
        .skip(index + 1)
        .fold(0, (count, entry) => count + entry.materializations.length);
  }
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
