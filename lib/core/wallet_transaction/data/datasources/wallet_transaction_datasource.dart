import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet_transaction/data/models/wallet_transaction_model.dart';

abstract class WalletTransactionDatasource {
  Future<List<WalletTransactionModel>> getTransactions({
    required PublicWalletModel wallet,
    String? toAddress,
  });
  Future<void> sync({
    required PublicWalletModel wallet,
    required ElectrumServerModel electrumServer,
  });
}
