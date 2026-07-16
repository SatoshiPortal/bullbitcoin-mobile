import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/public/remote_keychain_recovery_facade.dart';

final class RecoverRemoteKeychainUsecase {
  final RemoteKeychainRecoveryFacade remoteRecovery;

  const RecoverRemoteKeychainUsecase(this.remoteRecovery);

  void execute({required Set<String> defaultCreatedWalletIds}) =>
      unawaited(_recover(defaultCreatedWalletIds));

  Future<void> _recover(Set<String> defaultCreatedWalletIds) async {
    try {
      final result = await remoteRecovery.recover(
        defaultCreatedWalletIds: defaultCreatedWalletIds,
      );
      if (result.status != RemoteKeychainRecoveryStatus.noBackup &&
          result.status != RemoteKeychainRecoveryStatus.restored) {
        log.warning(
          'Optional remote keychain recovery did not complete: '
          '${result.status.name}',
        );
      }
    } catch (error, stack) {
      log.warning(
        'Optional remote keychain recovery failed',
        error: error,
        trace: stack,
      );
    }
  }
}
