import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/utxo_model.dart';

abstract class WalletDatasource {
  Future<List<UtxoModel>> getUtxos({
    required PublicWalletModel wallet,
  });
}
