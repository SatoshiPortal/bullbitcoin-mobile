import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';

abstract class WalletTransactionRepository {
  //Stream<WalletTransaction> get walletTransactions;
  Future<List<WalletTransaction>> getBroadcastedWalletTransactions({
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<List<WalletTransaction>> getOngoingPayjoinWalletTransactions({
    String? walletId,
    Environment? environment,
    bool sync = false,
  });
  Future<WalletTransaction> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });
}
