import 'package:bb_mobile/features/wallets/domain/entities/wallet_transaction_entity.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_output_vo.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_balance_vo.dart';

abstract class WalletPort {
  Future<WalletBalanceVO> getBalance(int walletId);
  Future<List<WalletTransactionEntity>> getTransactions(int walletId);
  Future<List<WalletOutputVO>> getUnspentOutputs(int walletId);
}
