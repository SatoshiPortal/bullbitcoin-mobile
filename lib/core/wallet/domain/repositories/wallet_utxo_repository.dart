import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

abstract class WalletUtxoRepository {
  Future<List<WalletUtxo>> getWalletUtxos({
    required String walletId,
  });
}
