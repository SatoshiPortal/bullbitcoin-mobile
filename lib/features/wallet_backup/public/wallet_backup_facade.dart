import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

export '../domain/entities/bullvault_backup_entry.dart';
export '../domain/entities/wallet_backup_inspection.dart';
export '../domain/entities/wallet_backup_remote_head.dart';
export '../domain/entities/wallet_backup_snapshot.dart';
export '../domain/entities/wallet_backup_state.dart';
export '../domain/wallet_backup_failure.dart';

class WalletBackupFacade {
  final GetWalletBackupControlUsecase _getControl;
  final InspectWalletBackupUsecase _inspect;

  const WalletBackupFacade(this._getControl, this._inspect);

  @useResult
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl() =>
      _getControl.execute();

  @useResult
  Future<Result<WalletBackupInspection, WalletBackupFailure>> inspect({
    String? words,
  }) => _inspect.execute(words: words);
}
