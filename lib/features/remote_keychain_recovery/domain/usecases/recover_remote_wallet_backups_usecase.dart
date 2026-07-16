import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';

typedef _RecoverKeychain = Future<RemoteKeychainRecoveryResult> Function();

final class RecoverRemoteWalletBackupsUsecase {
  final _RecoverKeychain _recoverKeychain;
  final WalletMetadataBackupFacade _metadataBackup;

  const RecoverRemoteWalletBackupsUsecase(
    this._recoverKeychain,
    this._metadataBackup,
  );

  Future<RemoteKeychainRecoveryResult> execute({
    required Set<String> defaultCreatedWalletIds,
  }) async {
    WalletMetadataRecoverySession? session;
    Object? keychainError;
    StackTrace? keychainStack;
    RemoteKeychainRecoveryResult? keychainResult;

    try {
      try {
        session = await _metadataBackup.beginRecoverySession();
      } catch (error, stack) {
        log.warning(
          'Could not suppress metadata publication during wallet recovery',
          error: error,
          trace: stack,
        );
      }

      try {
        keychainResult = await _recoverKeychain();
      } catch (error, stack) {
        keychainError = error;
        keychainStack = stack;
      }

      await _recoverMetadata(
        session: session,
        createdWalletRefs: {
          ...defaultCreatedWalletIds,
          ...?keychainResult?.createdWalletIds,
        },
      );
    } finally {
      session?.close();
    }

    if (keychainError != null) {
      Error.throwWithStackTrace(keychainError, keychainStack!);
    }
    return keychainResult!;
  }

  Future<void> _recoverMetadata({
    required WalletMetadataRecoverySession? session,
    required Set<String> createdWalletRefs,
  }) async {
    WalletMetadataRecoverySession? fallbackSession;
    try {
      final activeSession =
          session ??
          (fallbackSession = await _metadataBackup.beginRecoverySession());
      final result = await activeSession.recover(
        createdWalletRefs: Set.unmodifiable(createdWalletRefs),
      );
      if (result case Err(:final failure)) {
        log.warning(
          'Remote wallet metadata recovery failed',
          error: StateError(failure.runtimeType.toString()),
        );
      }
    } catch (error, stack) {
      log.warning(
        'Remote wallet metadata recovery threw unexpectedly',
        error: error,
        trace: stack,
      );
    } finally {
      fallbackSession?.close();
    }
  }
}
