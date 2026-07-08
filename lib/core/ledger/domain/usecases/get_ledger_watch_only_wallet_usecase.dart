import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class GetLedgerWatchOnlyWalletUsecase {
  final LedgerDeviceRepository _repository;

  GetLedgerWatchOnlyWalletUsecase({required this._repository});

  @useResult
  Future<Result<WatchOnlyWalletEntity, LedgerFailure>> execute({
    required String label,
    required LedgerDeviceEntity device,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) {
    return _repository.getWatchOnlyWallet(
      device,
      label: label,
      scriptType: scriptType,
      account: account,
    );
  }
}
