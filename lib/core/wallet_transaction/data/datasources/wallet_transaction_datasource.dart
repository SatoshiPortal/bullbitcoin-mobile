import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet_transaction/data/models/wallet_transaction_model.dart';

abstract class WalletTransactionDatasource {
  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  });
  Future<void> sync({
    required WalletModel wallet,
    required ElectrumServerModel electrumServer,
  });
}
