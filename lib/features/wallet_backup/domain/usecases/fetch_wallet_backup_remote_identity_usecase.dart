import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_identity.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

class FetchWalletBackupRemoteIdentityUsecase {
  final WalletBackupRemoteRepository _remote;

  const FetchWalletBackupRemoteIdentityUsecase(this._remote);

  @useResult
  Future<Result<WalletBackupRemoteIdentity, WalletBackupFailure>>
  execute() async {
    return (await _remote.fetch()).map(WalletBackupRemoteIdentity.fromHead);
  }
}
