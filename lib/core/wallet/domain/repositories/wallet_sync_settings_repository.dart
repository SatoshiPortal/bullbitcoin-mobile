import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show WalletBirthday;
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSyncSource;

abstract interface class WalletSyncSettingsRepository {
  @useResult
  Future<Result<WalletSyncSettings, WalletFailure>> getSyncSettings(
    String walletId,
  );

  @useResult
  Future<Result<void, WalletFailure>> updateBitcoinSyncSource({
    required String walletId,
    required BitcoinSyncSource source,
  });

  @useResult
  Future<Result<void, WalletFailure>> updateBitcoinSyncSettings({
    required String walletId,
    required BitcoinSyncSource source,
    required WalletBirthday? birthday,
    bool earlierOnly = false,
  });
}
