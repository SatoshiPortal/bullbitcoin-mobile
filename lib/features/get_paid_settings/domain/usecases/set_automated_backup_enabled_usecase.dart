import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

final class SetAutomatedBackupEnabledUsecase {
  final KeychainManifestFacade keychainManifest;

  const SetAutomatedBackupEnabledUsecase(this.keychainManifest);

  Future<void> execute(bool enabled) async {
    await keychainManifest.setBackupEnabled(enabled);
    if (!enabled) return;

    try {
      await keychainManifest.backupNow();
    } catch (error, stack) {
      log.warning('Initial keychain backup failed', error: error, trace: stack);
    }
  }
}
