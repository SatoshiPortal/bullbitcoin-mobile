import 'package:bb_mobile/core/transaction/data/models/transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';

abstract class TransactionDatasource {
  Future<List<TransactionModel>> getTransactions({
    required PublicWalletModel wallet,
  });
}
