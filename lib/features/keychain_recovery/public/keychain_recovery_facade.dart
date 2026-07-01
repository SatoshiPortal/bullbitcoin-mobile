import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/restore_keychain_manifest_wallets_usecase.dart';

export 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';

class KeychainRecoveryFacade {
  final RestoreKeychainManifestWalletsUsecase _restoreWallets;

  const KeychainRecoveryFacade({required this._restoreWallets});

  Future<KeychainRecoveryResult> restoreWallets(
    KeychainManifestImportPlan importPlan,
  ) async {
    return _restoreWallets.execute(importPlan);
  }
}
