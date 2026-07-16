import 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/recover_remote_wallet_backups_usecase.dart';

export 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';

final class RemoteKeychainRecoveryFacade {
  final RecoverRemoteWalletBackupsUsecase recoverWalletBackups;

  const RemoteKeychainRecoveryFacade(this.recoverWalletBackups);

  Future<RemoteKeychainRecoveryResult> recover({
    Set<String> defaultCreatedWalletIds = const {},
  }) {
    return recoverWalletBackups.execute(
      defaultCreatedWalletIds: Set.unmodifiable(defaultCreatedWalletIds),
    );
  }
}
