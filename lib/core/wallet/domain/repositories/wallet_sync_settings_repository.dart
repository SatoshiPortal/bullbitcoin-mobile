import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSyncSource;

abstract interface class WalletSyncSettingsRepository {
  @useResult
  Future<Result<void, WalletFailure>> updateBitcoinSyncSource({
    required String walletId,
    required BitcoinSyncSource source,
  });
}
