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
      Set<String> defaultCreatedWalletIds,
      bool callerSettlesFence,
      DateTime? deadline,
    });

/// Remote recovery: fetch the head, turn it into the shared typed snapshot,
/// and hand it to the one fenced apply path (spec F21, 19.7).
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
    Set<String> defaultCreatedWalletIds = const {},
  }) async {
    final WalletBackupRemoteHead initialHead;
    switch (await _fetchRemote()) {
      case Ok(:final value):
        initialHead = value;
      case Err(:final failure):
        return _apply(
          snapshot: Err(failure),
          defaultCreatedWalletIds: defaultCreatedWalletIds,
        );
    }
    final snapshot = await _fetchImport(initialHead);
    return _apply(
      defaultCreatedWalletIds: defaultCreatedWalletIds,
      snapshot: snapshot,
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
