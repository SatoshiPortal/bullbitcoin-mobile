import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_transaction.dart';

abstract class WalletTransactionRepository {
  //Stream<WalletTransaction> get walletTransactions;
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<WalletTransaction?> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });
}
