import 'package:bb_mobile/features/utxos/domain/ports/wallets_port.dart';
import 'package:bb_mobile/features/utxos/domain/utxo.dart';

class WalletsGateway implements WalletsPort {
  @override
  Future<Utxo?> getUtxo(String walletId, String txId, int index) {
    // TODO: implement getUtxo
    throw UnimplementedError();
  }

  @override
  Future<List<Utxo>> getUtxos(String walletId) {
    // TODO: implement getUtxos
    throw UnimplementedError();
  }
}
