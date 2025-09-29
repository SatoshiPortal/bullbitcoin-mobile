import 'package:bb_mobile/features/utxos/domain/utxo.dart';

abstract class WalletsPort {
  Future<Utxo?> getUtxo(String walletId, String txId, int index);
  Future<List<Utxo>> getUtxos(String walletId);
}
