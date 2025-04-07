import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';

abstract class BitcoinWalletRepository {
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    required int amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<Utxo>? unspendable,
    List<Utxo>? selected,
    bool? replaceByFee,
  });
  Future<String> signPsbt(
    String psbt, {
    required String walletId,
  });
}
