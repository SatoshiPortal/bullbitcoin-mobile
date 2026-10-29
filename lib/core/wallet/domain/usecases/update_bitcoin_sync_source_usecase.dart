import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSyncSource;

class UpdateBitcoinSyncSourceUsecase {
  final WalletSyncSettingsRepository _repository;

  UpdateBitcoinSyncSourceUsecase({required this._repository});

  @useResult
  Future<Result<void, WalletFailure>> execute({
    required String walletId,
    required BitcoinSyncSource source,
  }) => _repository.updateBitcoinSyncSource(walletId: walletId, source: source);
}
