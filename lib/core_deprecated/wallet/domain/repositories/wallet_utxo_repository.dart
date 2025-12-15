import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_utxo.dart';

abstract class WalletUtxoRepository {
  Future<List<WalletUtxo>> getWalletUtxos({
    required String walletId,
  });
}
