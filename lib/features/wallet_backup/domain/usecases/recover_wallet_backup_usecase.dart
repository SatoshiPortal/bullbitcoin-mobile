import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

typedef FetchWalletBackupImport =
    Future<Result<WalletBackupSnapshot?, WalletBackupFailure>> Function(
      WalletBackupRemoteHead remote,
    );
typedef ApplyFetchedWalletBackup =
    Future<WalletBackupRecoveryResult> Function({
      required Result<WalletBackupSnapshot?, WalletBackupFailure> snapshot,
      ValidateWalletBackupRecovery? revalidate,
      WalletBackupRemoteCheckpoint? appliedCheckpoint,
      List<WalletPreferences> defaultCreatedWalletPreferences,
      bool callerSettlesFence,
      DateTime? deadline,
    });

/// Remote recovery: fetch the head, turn it into the shared typed snapshot,
/// and hand it to the one fenced apply path.
final class RecoverWalletBackupUsecase {
  final FetchWalletBackupImport _fetchImport;
  final Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> Function()
  _fetchRemote;
  final ApplyFetchedWalletBackup _apply;

  const RecoverWalletBackupUsecase({
    required this._fetchImport,
    required this._fetchRemote,
    required this._apply,
  });

  Future<WalletBackupRecoveryResult> execute({
    List<WalletPreferences> defaultCreatedWalletPreferences = const [],
  }) async {
    final WalletBackupRemoteHead initialHead;
    switch (await _fetchRemote()) {
      case Ok(:final value):
        initialHead = value;
      case Err(:final failure):
        return _apply(
          snapshot: Err(failure),
          defaultCreatedWalletPreferences: defaultCreatedWalletPreferences,
        );
    }
    final snapshot = await _fetchImport(initialHead);
    return _apply(
      defaultCreatedWalletPreferences: defaultCreatedWalletPreferences,
      snapshot: snapshot,
      appliedCheckpoint: initialHead.checkpoint,
      revalidate: () async => switch (await _fetchRemote()) {
        Ok(:final value) => Ok(_sameRemoteObject(value, initialHead)),
        Err(:final failure) => Err(failure),
      },
    );
  }
}

bool _sameRemoteObject(
  WalletBackupRemoteHead left,
  WalletBackupRemoteHead right,
) => switch ((left.checkpoint, right.checkpoint)) {
  (null, null) => true,
  (final a?, final b?) => a.sameObjectAs(b),
  _ => false,
};
