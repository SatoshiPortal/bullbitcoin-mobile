import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';

abstract class UtxoRepository {
  Future<List<Utxo>> getUtxos({
    required String walletId,
  });
}
