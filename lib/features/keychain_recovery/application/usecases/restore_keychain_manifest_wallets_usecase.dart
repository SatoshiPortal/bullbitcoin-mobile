import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/application/ports/keychain_recovery_wallet_materializer_port.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';

class RestoreKeychainManifestWalletsUsecase {
  final KeychainRecoveryWalletMaterializerPort _walletMaterializer;
  final KeychainManifestFacade _keychainManifest;
  final Bip85RegistryFacade _bip85Registry;

  const RestoreKeychainManifestWalletsUsecase({
    required this._walletMaterializer,
    required this._keychainManifest,
    required this._bip85Registry,
  });

  Future<KeychainRecoveryResult> execute(
    KeychainManifestImportPlan importPlan,
  ) async {
    final outcomes = <KeychainRecoveryWalletRestoreOutcome>[];
    for (final entry in importPlan.entries) {
      final reservation = _bip85Registry.reservationById(entry.reservationId);
      if (reservation == null) {
        outcomes.addAll(
          entry.walletMaterializations.map(
            (intent) => KeychainRecoveryWalletRestoreOutcome(
              intent: intent,
              status: KeychainRecoveryWalletRestoreStatus.failedWalletCreation,
              walletId: intent.walletId,
            ),
          ),
        );
        continue;
      }
      final materializationResult = await _walletMaterializer.materialize(
        KeychainRecoveryWalletMaterializationBatch(
          parentFingerprint: importPlan.parentFingerprint,
          reservationId: entry.reservationId,
          bip85DerivationPath: entry.bip85DerivationPath,
          bip85Index: reservation.walletIndex,
          intents: entry.walletMaterializations,
        ),
      );
      outcomes.addAll(materializationResult.failedOutcomes);
      outcomes.addAll(
        await _recordMaterializedWallets(
          parentFingerprint: importPlan.parentFingerprint,
          reservationId: entry.reservationId,
          materializationResult: materializationResult,
        ),
      );
    }
    return KeychainRecoveryResult(walletOutcomes: outcomes);
  }

  Future<List<KeychainRecoveryWalletRestoreOutcome>>
  _recordMaterializedWallets({
    required String parentFingerprint,
    required String reservationId,
    required KeychainRecoveryWalletMaterializationResult materializationResult,
  }) async {
    final wallets = materializationResult.materializedWallets;
    final derivationPath = materializationResult.derivationPath;
    if (wallets.isEmpty || derivationPath == null) return [];
    try {
      await _keychainManifest.recordReservedDerivation(
        KeychainManifestReservedDerivationRequest(
          reservationId: reservationId,
          parentFingerprint: parentFingerprint,
          derivationPath: derivationPath,
          materializations: wallets
              .map(
                (wallet) => KeychainManifestWalletMaterializationRequest(
                  walletId: wallet.walletId,
                  childSeedFingerprint: wallet.childSeedFingerprint,
                  network: wallet.intent.network,
                  scriptType: wallet.intent.scriptType,
                ),
              )
              .toList(growable: false),
        ),
      );
      return wallets
          .map((wallet) {
            return KeychainRecoveryWalletRestoreOutcome(
              intent: wallet.intent,
              status: wallet.created
                  ? KeychainRecoveryWalletRestoreStatus.created
                  : KeychainRecoveryWalletRestoreStatus.alreadyPresent,
              walletId: wallet.walletId,
            );
          })
          .toList(growable: false);
    } on KeychainManifestException {
      return wallets
          .map((wallet) {
            return KeychainRecoveryWalletRestoreOutcome(
              intent: wallet.intent,
              status: KeychainRecoveryWalletRestoreStatus.failedManifestRecord,
              walletId: wallet.walletId,
            );
          })
          .toList(growable: false);
    }
  }
}
