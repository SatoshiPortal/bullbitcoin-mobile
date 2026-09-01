import 'package:bb_mobile/core/wallet/domain/entities/seed_derived_wallet_recovery_fact.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

final class RefreshWalletRecoveryManifestUsecase {
  final Future<List<SeedDerivedWalletRecoveryFact>> Function() _getWallets;
  final KeychainManifestFacade _manifest;

  const RefreshWalletRecoveryManifestUsecase(this._getWallets, this._manifest);

  Future<Result<void, WalletBackupFailure>> execute(
    Fingerprint parentFingerprint,
  ) async {
    try {
      final facts = await _getWallets();
      final result = await _manifest.replaceSeedWalletInventory(
        parentFingerprint: parentFingerprint,
        wallets: [
          for (final fact in facts)
            KeychainManifestWalletInventoryBinding(
              walletId: fact.walletId,
              seedFingerprint: fact.seedFingerprint,
              network: fact.network,
              scriptType: fact.scriptType,
              provenance: fact.provenance,
              derivationPath: fact.derivationPath,
              seedPassphraseUsed: fact.seedPassphraseUsed,
            ),
        ],
      );
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(
          WalletBackupManifestFailure(failure.runtimeType.toString()),
        ),
      };
    } on Exception catch (error) {
      return Err(WalletBackupStorageFailure(error.runtimeType.toString()));
    }
  }
}
