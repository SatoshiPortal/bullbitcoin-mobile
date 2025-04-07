import 'package:bb_mobile/core/utxo/data/models/utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';

abstract class UtxoDatasource {
  Future<List<UtxoModel>> getUtxos({
    required PublicWalletModel wallet,
  });
  /*
  /// Fetches the UTXO set for a given address.
  ///
  /// Returns a list of UTXOs associated with the address.
  Future<List<Utxo>> fetchUtxos(
    String address, {
    required PublicWalletModel publicWalletModel,
  });

  /// Fetches the UTXO set for a given transaction ID.
  ///
  /// Returns a list of UTXOs associated with the transaction ID.
  Future<List<Utxo>> fetchUtxosByTransactionId(String transactionId, {
    required PublicWalletModel publicWalletModel,
  });
  */
}
