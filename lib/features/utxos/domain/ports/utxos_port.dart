import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/utxos/domain/utxo.dart';

abstract class UtxosPort {
  Future<Utxo?> getUtxoFromWallet({
    required String txId,
    required int index,
    required Wallet wallet,
  });
  Future<List<Utxo>> getUtxosFromWallet(
    Wallet wallet, {
    int? limit,
    int? offset,
  });
}
