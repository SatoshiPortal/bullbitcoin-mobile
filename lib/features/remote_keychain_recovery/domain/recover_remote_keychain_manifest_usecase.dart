import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/public/keychain_recovery_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/heal_recovered_products_usecase.dart';

final class RecoverRemoteKeychainManifestUsecase {
  final KeychainManifestFacade manifest;
  final KeychainRecoveryFacade recovery;
  final HealRecoveredProductsUsecase healRecoveredProducts;

  const RecoverRemoteKeychainManifestUsecase({
    required this.manifest,
    required this.recovery,
    required this.healRecoveredProducts,
  });

  Future<RemoteKeychainRecoveryResult> execute() async {
    final remote = await manifest.fetchRemoteImportPlan();
    if (remote.importPlan == null) {
      return RemoteKeychainRecoveryResult(
        status: switch (remote.status) {
          KeychainManifestRemoteImportStatus.absent =>
            RemoteKeychainRecoveryStatus.noBackup,
          KeychainManifestRemoteImportStatus.unavailable =>
            RemoteKeychainRecoveryStatus.unavailable,
          KeychainManifestRemoteImportStatus.invalid =>
            RemoteKeychainRecoveryStatus.invalid,
          KeychainManifestRemoteImportStatus.tooLarge =>
            RemoteKeychainRecoveryStatus.tooLarge,
          KeychainManifestRemoteImportStatus.newerVersion =>
            RemoteKeychainRecoveryStatus.newerVersion,
          KeychainManifestRemoteImportStatus.conflict =>
            RemoteKeychainRecoveryStatus.conflict,
          KeychainManifestRemoteImportStatus.success =>
            RemoteKeychainRecoveryStatus.invalid,
        },
      );
    }

    final restored = await recovery.restoreWallets(remote.importPlan!);
    final failed = restored.walletOutcomes
        .where((outcome) => !outcome.succeeded)
        .length;
    final reactivationReservationIds = restored
        .productReactivationRequiredOutcomes
        .map((outcome) => outcome.intent.reservationId)
        .toSet();
    final healOutcome =
        restored.restoredCount > 0 && reactivationReservationIds.isNotEmpty
        ? await healRecoveredProducts.execute(reactivationReservationIds)
        : null;
    return RemoteKeychainRecoveryResult(
      status: failed == 0
          ? RemoteKeychainRecoveryStatus.restored
          : RemoteKeychainRecoveryStatus.partiallyRestored,
      restoredCount: restored.restoredCount,
      failedCount: failed,
      createdWalletIds: restored.walletOutcomes
          .where(
            (outcome) =>
                outcome.status == KeychainRecoveryWalletRestoreStatus.created,
          )
          .map((outcome) => outcome.walletId)
          .toList(growable: false),
      healOutcome: healOutcome,
    );
  }
}
